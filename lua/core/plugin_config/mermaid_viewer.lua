-- ============================================================================
-- mermaid_viewer.lua  --  zoomable mermaid preview
--
-- Renders mermaid source as an image (kitty graphics, via image.nvim) in a
-- dedicated, ZOOMABLE/PANNABLE side split. Two entry points:
--
--   * standalone *.mmd / *.mermaid files  -- the file stays an editable text
--     buffer; the preview tracks the whole buffer and re-renders on save/edit.
--
--   * a ```mermaid``` block inside markdown -- pops the block under the cursor
--     into the same zoom viewer. (The inline render from diagram.nvim is fixed
--     to text size and can't zoom; this is how you blow one up.)
--
-- Commands / keymaps:
--   :MermaidPreview        preview current .mmd file OR the block under cursor
--   :MermaidPreviewClose   close the preview for this buffer
--   .mmd files     : <leader>mm preview   <leader>mc close
--   markdown files : <leader>mm zoom the mermaid block under the cursor
--   inside the preview window:  + / - zoom   0 reset   h/j/k/l pan
--                               r re-render   q close
-- ============================================================================

local M = {}

local has_image, image_api = pcall(require, "image")

M.config = {
  theme = "forest",
  background = "transparent",
  scale = 3, -- supersample for crisp kitty-graphics output
  split_width = 0.5, -- preview width as a fraction of the editor columns
  cell_ratio = 2.0, -- terminal cell height:width; used only for fit/centering
  pan_step = 4,
}

-- per-preview state, keyed by an opaque string (see open_file / open_block)
local state = {}
local next_id = 0

-- ---------------------------------------------------------------------------
-- markdown block extraction (treesitter)
-- ---------------------------------------------------------------------------

local md_query
local function get_md_query()
  if not md_query then
    md_query = vim.treesitter.query.parse(
      "markdown",
      "(fenced_code_block (info_string) @info (code_fence_content) @code)"
    )
  end
  return md_query
end

-- find the ```mermaid``` block whose range contains `row` (0-indexed); pass
-- row=nil for "the first mermaid block". Returns { source, start_row } or nil.
local function mermaid_block_at(buf, row)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return nil
  end
  parser:parse(true)
  local root = parser:parse()[1]:root()
  local q = get_md_query()
  local info
  for id, node in q:iter_captures(root, buf) do
    local cap = q.captures[id]
    if cap == "info" then
      info = vim.treesitter.get_node_text(node, buf)
    elseif cap == "code" then
      if info and info:match("^mermaid") then
        local block = node:parent()
        local sr, _, er = block:range()
        if row == nil or (row >= sr and row <= er) then
          return { source = vim.treesitter.get_node_text(node, buf), start_row = sr }
        end
      end
      info = nil
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- rendering helpers
-- ---------------------------------------------------------------------------

-- render mermaid source to a png (cached by content hash); calls cb(png_path)
-- on success. Async -- never blocks the editor.
local function render_png(st, source, cb)
  local hash = vim.fn.sha256(M.config.theme .. M.config.scale .. source)
  local png = st.tmp .. "/" .. hash .. ".png"
  if vim.fn.filereadable(png) == 1 then
    cb(png)
    return
  end

  local src = st.tmp .. "/src.mmd"
  vim.fn.writefile(vim.split(source, "\n"), src)

  vim.system({
    "mmdc",
    "-i", src,
    "-o", png,
    "-t", M.config.theme,
    "-b", M.config.background,
    "-s", tostring(M.config.scale),
  }, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 and vim.fn.filereadable(png) == 1 then
        cb(png)
      else
        local msg = (res.stderr ~= "" and res.stderr) or (res.stdout or "unknown error")
        vim.notify("mermaid: render failed\n" .. msg, vim.log.levels.ERROR)
      end
    end)
  end)
end

-- contain-fit the png (pixels pw x ph) inside the preview window, centered,
-- scaled by the current zoom. Returns cell-grid geometry for image.nvim.
local function compute_geometry(st, win, pw, ph)
  local win_w = vim.api.nvim_win_get_width(win)
  local win_h = vim.api.nvim_win_get_height(win)
  local avail_w = math.max(1, win_w - 2)
  local avail_h = math.max(1, win_h - 1)
  local aspect = pw / ph
  local cr = M.config.cell_ratio

  -- fit-by-height, fall back to fit-by-width
  local h = avail_h
  local w = math.floor(h * aspect * cr + 0.5)
  if w > avail_w then
    w = avail_w
    h = math.floor(w / (aspect * cr) + 0.5)
  end

  w = math.max(1, math.floor(w * st.zoom + 0.5))
  h = math.max(1, math.floor(h * st.zoom + 0.5))

  local x = math.max(0, math.floor((win_w - w) / 2) + (st.pan_x or 0))
  local y = math.max(0, math.floor((win_h - h) / 2) + (st.pan_y or 0))
  return { x = x, y = y, w = w, h = h, win_h = win_h }
end

local function fill_buffer(buf, n)
  n = math.max(n, 1)
  if vim.api.nvim_buf_line_count(buf) == n then
    return
  end
  local lines = {}
  for _ = 1, n do
    lines[#lines + 1] = ""
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

-- (re)draw the diagram for `key` into its preview window
function M.render(key)
  local st = state[key]
  if not st or not has_image then
    return
  end
  if not (st.pwin and vim.api.nvim_win_is_valid(st.pwin)) then
    return
  end
  if not (st.pbuf and vim.api.nvim_buf_is_valid(st.pbuf)) then
    return
  end

  local source = st.source_fn()
  if not source or source:match("^%s*$") then
    return -- nothing to render (empty buffer / block went away)
  end

  st.seq = (st.seq or 0) + 1
  local seq = st.seq

  render_png(st, source, function(png)
    -- bail if a newer render started or the preview was closed meanwhile
    if not state[key] or st.seq ~= seq then
      return
    end
    if not (st.pwin and vim.api.nvim_win_is_valid(st.pwin)) then
      return
    end

    local dims = vim.fn.systemlist({ "identify", "-format", "%w %h", png })[1] or ""
    local pw, ph = dims:match("(%d+)%s+(%d+)")
    pw, ph = tonumber(pw) or 1032, tonumber(ph) or 1068

    local g = compute_geometry(st, st.pwin, pw, ph)
    fill_buffer(st.pbuf, g.win_h)

    if st.image then
      pcall(function() st.image:clear() end)
      st.image = nil
    end
    local ok, img = pcall(image_api.from_file, png, {
      id = "mermaid_" .. st.id,
      window = st.pwin,
      buffer = st.pbuf,
      x = g.x,
      y = g.y,
      width = g.w,
      height = g.h,
    })
    if ok and img then
      img.ignore_global_max_size = true -- the viewer sizes the diagram itself
      st.image = img
      pcall(function() img:render() end)
    elseif not ok then
      vim.notify("mermaid: " .. tostring(img), vim.log.levels.ERROR)
    end
  end)
end

-- ---------------------------------------------------------------------------
-- preview window lifecycle
-- ---------------------------------------------------------------------------

local function apply_win_opts(win)
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.cursorline = false
  wo.cursorcolumn = false
  wo.list = false
  wo.wrap = false
  wo.spell = false
  wo.signcolumn = "no"
  wo.colorcolumn = ""
  wo.foldcolumn = "0"
  wo.winbar = "  mermaid   +/- zoom  0 reset  hjkl pan  r redraw  q close "
end

function M.close(key)
  local st = state[key]
  if not st then
    return
  end
  if st.image then
    pcall(function() st.image:clear() end)
  end
  pcall(vim.api.nvim_del_augroup_by_name, st.augroup)
  if st.ns and st.mark and st.src_buf and vim.api.nvim_buf_is_valid(st.src_buf) then
    pcall(vim.api.nvim_buf_del_extmark, st.src_buf, st.ns, st.mark)
  end
  if st.pwin and vim.api.nvim_win_is_valid(st.pwin) then
    pcall(vim.api.nvim_win_close, st.pwin, true)
  end
  if st.pbuf and vim.api.nvim_buf_is_valid(st.pbuf) then
    pcall(vim.api.nvim_buf_delete, st.pbuf, { force = true })
  end
  pcall(vim.fn.delete, st.tmp, "rf")
  state[key] = nil
end

-- close any preview attached to the given source buffer
function M.close_for_buf(buf)
  for key, st in pairs(state) do
    if st.src_buf == buf then
      M.close(key)
    end
  end
end

local function set_zoom(key, z)
  local st = state[key]
  if not st then
    return
  end
  st.zoom = math.max(0.25, math.min(8, z))
  st.pan_x, st.pan_y = 0, 0
  M.render(key)
end

local function pan(key, dx, dy)
  local st = state[key]
  if not st then
    return
  end
  st.pan_x = (st.pan_x or 0) + dx
  st.pan_y = (st.pan_y or 0) + dy
  M.render(key)
end

-- core: create (or refocus) the preview split for `key`.
-- opts = { key, src_buf, source_fn }
local function open(opts)
  local key = opts.key
  if not has_image then
    vim.notify("mermaid: image.nvim is not available", vim.log.levels.ERROR)
    return nil
  end
  if vim.fn.executable("mmdc") == 0 then
    vim.notify("mermaid: mmdc (mermaid-cli) not found in PATH", vim.log.levels.ERROR)
    return nil
  end

  -- already open -> swap in the (possibly new) source_fn and refresh
  local existing = state[key]
  if existing and existing.pwin and vim.api.nvim_win_is_valid(existing.pwin) then
    existing.source_fn = opts.source_fn
    M.render(key)
    return existing
  end

  local src_win = vim.api.nvim_get_current_win()

  local pbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[pbuf].bufhidden = "wipe"
  vim.bo[pbuf].filetype = "mermaidpreview"

  local width = math.floor(vim.o.columns * M.config.split_width)
  vim.cmd("noautocmd vertical rightbelow " .. width .. "vsplit")
  local pwin = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(pwin, pbuf)
  apply_win_opts(pwin)

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")

  next_id = next_id + 1
  state[key] = {
    id = next_id,
    src_buf = opts.src_buf,
    src_win = src_win,
    pwin = pwin,
    pbuf = pbuf,
    tmp = tmp,
    source_fn = opts.source_fn,
    zoom = 1.0,
    pan_x = 0,
    pan_y = 0,
    augroup = "MermaidPreview_" .. next_id,
  }

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = pbuf, silent = true, nowait = true })
  end
  local step = M.config.pan_step
  map("+", function() set_zoom(key, state[key].zoom * 1.25) end)
  map("=", function() set_zoom(key, state[key].zoom * 1.25) end)
  map("-", function() set_zoom(key, state[key].zoom / 1.25) end)
  map("0", function() set_zoom(key, 1.0) end)
  map("h", function() pan(key, step, 0) end)
  map("l", function() pan(key, -step, 0) end)
  map("k", function() pan(key, 0, step) end)
  map("j", function() pan(key, 0, -step) end)
  map("r", function() M.render(key) end)
  map("q", function() M.close(key) end)

  local grp = vim.api.nvim_create_augroup(state[key].augroup, { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "InsertLeave" }, {
    group = grp,
    buffer = opts.src_buf,
    callback = function() M.render(key) end,
  })
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = grp,
    callback = function() vim.schedule(function() M.render(key) end) end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = grp,
    buffer = opts.src_buf,
    callback = function() M.close(key) end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = grp,
    callback = function(ev)
      local st = state[key]
      if st and tonumber(ev.match) == st.pwin then
        M.close(key)
      end
    end,
  })

  -- focus stays on the source so you can keep editing
  vim.api.nvim_set_current_win(src_win)
  vim.schedule(function() M.render(key) end)
  return state[key]
end

-- ---------------------------------------------------------------------------
-- public entry points
-- ---------------------------------------------------------------------------

-- preview a whole .mmd / .mermaid buffer (whole-buffer source)
function M.open_file(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  open({
    key = "file:" .. buf,
    src_buf = buf,
    source_fn = function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end,
  })
end

-- zoom the ```mermaid``` block under the cursor in a markdown buffer. One
-- preview per markdown buffer -- invoking it on a different block re-points
-- the same window at that block. The block is tracked by an extmark so it
-- survives edits above it.
function M.open_block(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local blk = mermaid_block_at(buf, row) or mermaid_block_at(buf, nil)
  if not blk then
    vim.notify("mermaid: no mermaid block under the cursor", vim.log.levels.WARN)
    return
  end

  local key = "mdblock:" .. buf
  open({
    key = key,
    src_buf = buf,
    source_fn = function()
      local st = state[key]
      if not (st and st.mark) then
        return nil
      end
      local pos = vim.api.nvim_buf_get_extmark_by_id(buf, st.ns, st.mark, {})
      if not pos or not pos[1] then
        return nil
      end
      local b = mermaid_block_at(buf, pos[1])
      return b and b.source or nil
    end,
  })

  -- (re)anchor the tracking extmark to the chosen block, then redraw
  local st = state[key]
  if st then
    st.ns = st.ns or vim.api.nvim_create_namespace("mermaid_block")
    if st.mark then
      pcall(vim.api.nvim_buf_del_extmark, buf, st.ns, st.mark)
    end
    st.mark = vim.api.nvim_buf_set_extmark(buf, st.ns, blk.start_row, 0, {})
    M.render(key)
  end
end

-- filetype-aware dispatch for the :MermaidPreview command
function M.preview(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "mermaid" then
    M.open_file(buf)
  else
    M.open_block(buf)
  end
end

-- ---------------------------------------------------------------------------
-- setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  -- standalone mermaid files get their own filetype (editable text buffer)
  vim.filetype.add({ extension = { mmd = "mermaid", mermaid = "mermaid" } })

  vim.api.nvim_create_user_command("MermaidPreview", function()
    M.preview(vim.api.nvim_get_current_buf())
  end, { desc = "Preview the current mermaid file / block under cursor" })

  vim.api.nvim_create_user_command("MermaidPreviewClose", function()
    M.close_for_buf(vim.api.nvim_get_current_buf())
  end, { desc = "Close the mermaid preview for this buffer" })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "mermaid", "markdown" },
    callback = function(ev)
      vim.keymap.set("n", "<leader>mm", "<cmd>MermaidPreview<CR>",
        { buffer = ev.buf, desc = "Mermaid: zoomable preview" })
      vim.keymap.set("n", "<leader>mc", "<cmd>MermaidPreviewClose<CR>",
        { buffer = ev.buf, desc = "Mermaid: close preview" })
    end,
  })
end

M.setup()

return M
