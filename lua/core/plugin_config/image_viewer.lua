-- ============================================================================
-- image_viewer.lua  --  generic zoomable / pannable single-image preview engine
--
-- Owns the side split, zoom, pan, fit-geometry, image.nvim placement and the
-- whole window/autocmd lifecycle. It knows nothing about *what* it is showing:
-- an adapter (see mermaid_viewer.lua / drawio_viewer.lua) supplies a `render`
-- callback that turns the source buffer into a PNG on disk, and this module
-- blows it up in a dedicated window you can zoom and pan.
--
-- Adapters call V.open{...}; the engine returns the per-preview state table so
-- the adapter can stash its own fields on it (e.g. treesitter extmarks).
--
--   in the preview window:  + / - zoom   0 reset   h/j/k/l pan   r redraw  q close
-- ============================================================================

local V = {}

local has_image, image_api = pcall(require, "image")
V.has_image = has_image

V.defaults = {
  split_width = 0.5, -- preview width as a fraction of the editor columns
  cell_ratio = 2.0, -- terminal cell height:width; used only for fit/centering
  pan_step = 4,
}

-- per-preview state, keyed by an opaque adapter-supplied string
local state = {}
local next_id = 0

V.state = state -- exposed so adapters can read/attach fields (extmarks, etc.)

-- ---------------------------------------------------------------------------
-- geometry / buffer helpers
-- ---------------------------------------------------------------------------

-- contain-fit the png (pixels pw x ph) inside the preview window, centered,
-- scaled by the current zoom. Returns cell-grid geometry for image.nvim.
local function compute_geometry(st, win, pw, ph)
  local win_w = vim.api.nvim_win_get_width(win)
  local win_h = vim.api.nvim_win_get_height(win)
  local avail_w = math.max(1, win_w - 2)
  local avail_h = math.max(1, win_h - 1)
  local aspect = pw / ph
  local cr = st.cell_ratio

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
  return { x = x, y = y, w = w, h = h, win_h = win_h, win_w = win_w }
end

-- image.nvim resolves the image's `x` by buffer column (via screenpos), so the
-- filler lines must be padded with real columns -- empty lines collapse every
-- x>0 back to the left edge and horizontal panning does nothing. The spaces
-- sit under the image and are invisible.
local function fill_buffer(buf, n, width)
  n = math.max(n, 1)
  width = math.max(width or 0, 1)
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if vim.api.nvim_buf_line_count(buf) == n and first and #first == width then
    return
  end
  local line = string.rep(" ", width)
  local lines = {}
  for _ = 1, n do
    lines[#lines + 1] = line
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

-- ---------------------------------------------------------------------------
-- rendering
-- ---------------------------------------------------------------------------

-- (re)draw the diagram for `key`. Delegates PNG production to st.render, then
-- fits & places the result. st.render(st, cb) must call:
--   cb(png_path)      success -- place this image
--   cb(nil)           nothing to draw (empty source) -- silently skip
--   cb(nil, "msg")    failure -- notify the error
function V.render(key)
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

  st.seq = (st.seq or 0) + 1
  local seq = st.seq

  st.render(st, function(png, err)
    -- bail if a newer render started or the preview was closed meanwhile
    if not state[key] or st.seq ~= seq then
      return
    end
    if not png then
      if err then
        vim.notify(st.name .. ": " .. err, vim.log.levels.ERROR)
      end
      return
    end
    if not (st.pwin and vim.api.nvim_win_is_valid(st.pwin)) then
      return
    end

    local dims = vim.fn.systemlist({ "identify", "-format", "%w %h", png })[1] or ""
    local pw, ph = dims:match("(%d+)%s+(%d+)")
    pw, ph = tonumber(pw) or 1032, tonumber(ph) or 1068

    local g = compute_geometry(st, st.pwin, pw, ph)
    fill_buffer(st.pbuf, g.win_h, g.win_w)

    if st.image then
      pcall(function() st.image:clear() end)
      st.image = nil
    end
    local ok, img = pcall(image_api.from_file, png, {
      id = st.name .. "_" .. st.id,
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
      vim.notify(st.name .. ": " .. tostring(img), vim.log.levels.ERROR)
    end
  end)
end

-- ---------------------------------------------------------------------------
-- window lifecycle
-- ---------------------------------------------------------------------------

local function apply_win_opts(win, winbar)
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
  wo.winbar = winbar
end

function V.close(key)
  local st = state[key]
  if not st then
    return
  end
  if st.image then
    pcall(function() st.image:clear() end)
  end
  pcall(vim.api.nvim_del_augroup_by_name, st.augroup)
  -- adapter-specific cleanup (e.g. mermaid's block-tracking extmark)
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
function V.close_for_buf(buf)
  for key, st in pairs(state) do
    if st.src_buf == buf then
      V.close(key)
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
  V.render(key)
end

local function pan(key, dx, dy)
  local st = state[key]
  if not st then
    return
  end
  st.pan_x = (st.pan_x or 0) + dx
  st.pan_y = (st.pan_y or 0) + dy
  V.render(key)
end

-- create (or refocus) the preview split for `key`.
-- opts = {
--   key, src_buf,                      -- identity
--   name,                              -- short tag: image ids + notify prefix
--   winbar,                            -- preview window winbar text
--   render = function(st, cb) ... end, -- produce a PNG (see V.render)
--   watch_events = { "BufWritePost", ... },  -- src_buf events that re-render
--   tmp_dir = function(src_buf) -> dir,      -- scratch dir (created); default /tmp
--   split_width, cell_ratio, pan_step,       -- optional overrides
-- }
function V.open(opts)
  local key = opts.key
  if not has_image then
    vim.notify((opts.name or "viewer") .. ": image.nvim is not available", vim.log.levels.ERROR)
    return nil
  end

  -- already open -> swap in the (possibly new) render closure and refresh
  local existing = state[key]
  if existing and existing.pwin and vim.api.nvim_win_is_valid(existing.pwin) then
    existing.render = opts.render
    V.render(key)
    return existing
  end

  local src_win = vim.api.nvim_get_current_win()

  local pbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[pbuf].bufhidden = "wipe"
  vim.bo[pbuf].filetype = (opts.name or "image") .. "preview"

  local split_width = opts.split_width or V.defaults.split_width
  local width = math.floor(vim.o.columns * split_width)
  vim.cmd("noautocmd vertical rightbelow " .. width .. "vsplit")
  local pwin = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(pwin, pbuf)
  apply_win_opts(pwin, opts.winbar or "")

  local tmp
  if opts.tmp_dir then
    tmp = opts.tmp_dir(opts.src_buf)
  else
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
  end

  next_id = next_id + 1
  state[key] = {
    id = next_id,
    key = key,
    name = opts.name or "image",
    src_buf = opts.src_buf,
    src_win = src_win,
    pwin = pwin,
    pbuf = pbuf,
    tmp = tmp,
    render = opts.render,
    cell_ratio = opts.cell_ratio or V.defaults.cell_ratio,
    zoom = 1.0,
    pan_x = 0,
    pan_y = 0,
    augroup = "ImageViewer_" .. next_id,
  }

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = pbuf, silent = true, nowait = true })
  end
  local step = opts.pan_step or V.defaults.pan_step
  map("+", function() set_zoom(key, state[key].zoom * 1.25) end)
  map("=", function() set_zoom(key, state[key].zoom * 1.25) end)
  map("-", function() set_zoom(key, state[key].zoom / 1.25) end)
  map("0", function() set_zoom(key, 1.0) end)
  map("h", function() pan(key, step, 0) end)
  map("l", function() pan(key, -step, 0) end)
  map("k", function() pan(key, 0, step) end)
  map("j", function() pan(key, 0, -step) end)
  map("<Left>", function() pan(key, step, 0) end)
  map("<Right>", function() pan(key, -step, 0) end)
  map("<Up>", function() pan(key, 0, step) end)
  map("<Down>", function() pan(key, 0, -step) end)
  map("r", function() V.render(key) end)
  map("q", function() V.close(key) end)

  local grp = vim.api.nvim_create_augroup(state[key].augroup, { clear = true })
  if opts.watch_events and #opts.watch_events > 0 then
    vim.api.nvim_create_autocmd(opts.watch_events, {
      group = grp,
      buffer = opts.src_buf,
      callback = function() V.render(key) end,
    })
  end
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = grp,
    callback = function() vim.schedule(function() V.render(key) end) end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = grp,
    buffer = opts.src_buf,
    callback = function() V.close(key) end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = grp,
    callback = function(ev)
      local st = state[key]
      if st and tonumber(ev.match) == st.pwin then
        V.close(key)
      end
    end,
  })

  -- focus stays on the source so you can keep editing
  vim.api.nvim_set_current_win(src_win)
  vim.schedule(function() V.render(key) end)
  return state[key]
end

return V
