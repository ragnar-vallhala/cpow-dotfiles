-- ============================================================================
-- pdf_viewer.lua  --  a minimal PDF viewer for Neovim inside kitty
--
-- Opening any *.pdf renders its pages as images (kitty graphics protocol, via
-- image.nvim) with page navigation and zoom. Pages are rasterised on demand
-- with `pdftocairo` (poppler) and cached per (page, dpi) in a temp dir.
--
-- Keymaps inside a PDF buffer:
--   ]  / [        next / previous page      (also <Space> / <BS>, n / p)
--   gg / G        first / last page
--   + (or =) / -  zoom in / out      0  reset zoom
--   h j k l       pan (when zoomed in past the window edges)
--   r             re-render current page
--   q             close the viewer
-- ============================================================================

local M = {}

local has_image, image_api = pcall(require, "image")

-- per-buffer state, keyed by bufnr
local state = {}

M.config = {
  -- when true, opening a .pdf in nvim launches zathura externally (auto-reloads
  -- on rebuild). When false, falls back to the in-nvim kitty-graphics viewer
  -- below (no file watching — stale until :e).
  use_external = true,
  external_cmd = { "zathura", "--fork" },

  -- terminal cell height:width ratio; used only for centering / initial fit.
  -- aspect ratio is never distorted (image.nvim preserves it). Bump this if
  -- pages look too narrow, lower it if they overflow horizontally.
  cell_ratio = 2.0,
  pan_step = 6,
}

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function get_pdf_info(path)
  local info = { pages = 1, w = 612, h = 792 } -- US-letter fallback
  local out = vim.fn.systemlist({ "pdfinfo", path })
  if vim.v.shell_error ~= 0 then
    return info
  end
  for _, line in ipairs(out) do
    local p = line:match("^Pages:%s+(%d+)")
    if p then
      info.pages = tonumber(p)
    end
    local w, h = line:match("^Page size:%s+([%d%.]+)%s+x%s+([%d%.]+)")
    if w and h then
      info.w, info.h = tonumber(w), tonumber(h)
    end
  end
  return info
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

local function update_winbar(win, st)
  local name = vim.fn.fnamemodify(st.path, ":t")
  local text = string.format(
    "  %s   page %d/%d   %d%%   |  ]/[ pages   +/- zoom   q close ",
    name, st.page, st.info.pages, math.floor(st.zoom * 100 + 0.5)
  )
  pcall(vim.api.nvim_set_option_value, "winbar", text, { win = win })
end

local function compute_geometry(st, win)
  local win_w = vim.api.nvim_win_get_width(win)
  local win_h = vim.api.nvim_win_get_height(win)
  local avail_w = math.max(1, win_w - 4)
  local avail_h = math.max(1, win_h - 2)
  local page_aspect = st.info.w / st.info.h
  local cr = M.config.cell_ratio

  -- fit-by-height, fall back to fit-by-width
  local h = avail_h
  local w = math.floor(h * page_aspect * cr + 0.5)
  if w > avail_w then
    w = avail_w
    h = math.floor(w / (page_aspect * cr) + 0.5)
  end

  w = math.max(1, math.floor(w * st.zoom + 0.5))
  h = math.max(1, math.floor(h * st.zoom + 0.5))

  local x = math.floor((win_w - w) / 2) + (st.pan_x or 0)
  local y = math.floor((win_h - h) / 2) + (st.pan_y or 0)
  return { x = x, y = y, w = w, h = h, win_w = win_w, win_h = win_h }
end

-- rasterise one page (cached); calls cb(png_path) on success
local function page_png(st, page, dpi, cb)
  local key = page .. "@" .. dpi
  local cached = st.cache[key]
  if cached and vim.fn.filereadable(cached) == 1 then
    cb(cached)
    return
  end
  local prefix = string.format("%s/p%d_%d", st.tmp, page, dpi)
  vim.system({
    "pdftocairo", "-png", "-singlefile",
    "-r", tostring(dpi),
    "-f", tostring(page), "-l", tostring(page),
    st.path, prefix,
  }, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        st.cache[key] = prefix .. ".png"
        cb(st.cache[key])
      else
        vim.notify(
          "pdf-viewer: failed to render page " .. page .. "\n" .. (res.stderr or ""),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

-- ---------------------------------------------------------------------------
-- rendering
-- ---------------------------------------------------------------------------

function M.render(buf)
  local st = state[buf]
  if not st or not has_image then
    return
  end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    return
  end

  local g = compute_geometry(st, win)
  fill_buffer(buf, g.win_h)

  -- dpi chosen so the rasterised page is a touch denser than the cell grid,
  -- keeping it crisp at the current zoom level
  local dpi = math.floor(math.min(350, math.max(72, g.h * 26 * 72 / st.info.h)))

  st.seq = (st.seq or 0) + 1
  local seq = st.seq

  page_png(st, st.page, dpi, function(png)
    if not state[buf] or st.seq ~= seq then
      return -- a newer render superseded this one
    end
    local w = vim.fn.bufwinid(buf)
    if w == -1 then
      return
    end
    if st.image then
      pcall(function() st.image:clear() end)
      st.image = nil
    end
    local ok, img = pcall(image_api.from_file, png, {
      id = "pdfviewer_" .. buf .. "_" .. seq,
      window = w,
      buffer = buf,
      x = g.x,
      y = g.y,
      width = g.w,
      height = g.h,
    })
    if ok and img then
      -- bypass image.nvim's global caps (notably the default 50% window-height
      -- limit) -- the viewer sizes pages itself
      img.ignore_global_max_size = true
      st.image = img
      pcall(function() img:render() end)
    elseif not ok then
      vim.notify("pdf-viewer: " .. tostring(img), vim.log.levels.ERROR)
    end
    update_winbar(w, st)
  end)

  -- prefetch the next page so forward navigation feels instant
  if st.page < st.info.pages then
    page_png(st, st.page + 1, dpi, function() end)
  end
end

-- ---------------------------------------------------------------------------
-- actions
-- ---------------------------------------------------------------------------

local function set_page(buf, p)
  local st = state[buf]
  if not st then
    return
  end
  p = math.max(1, math.min(st.info.pages, p))
  if p == st.page then
    return
  end
  st.page, st.pan_x, st.pan_y = p, 0, 0
  M.render(buf)
end

local function set_zoom(buf, z)
  local st = state[buf]
  if not st then
    return
  end
  st.zoom = math.max(0.25, math.min(8, z))
  st.pan_x, st.pan_y = 0, 0
  M.render(buf)
end

local function pan(buf, dx, dy)
  local st = state[buf]
  if not st then
    return
  end
  st.pan_x = (st.pan_x or 0) + dx
  st.pan_y = (st.pan_y or 0) + dy
  M.render(buf)
end

local function apply_win_opts(buf)
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    return
  end
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
end

function M.close(buf)
  local st = state[buf]
  if not st then
    return
  end
  if st.image then
    pcall(function() st.image:clear() end)
  end
  pcall(vim.fn.delete, st.tmp, "rf")
  pcall(vim.api.nvim_del_augroup_by_name, "PdfViewer_" .. buf)
  state[buf] = nil
end

-- ---------------------------------------------------------------------------
-- open
-- ---------------------------------------------------------------------------

function M.open(buf)
  if not has_image then
    vim.notify("pdf-viewer: image.nvim is not available", vim.log.levels.ERROR)
    return
  end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) == 0 then
    return
  end
  if state[buf] then
    M.close(buf) -- reopened with :e -- start fresh
  end

  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")

  state[buf] = {
    path = path,
    page = 1,
    zoom = 1.0,
    pan_x = 0,
    pan_y = 0,
    tmp = tmp,
    cache = {},
    info = get_pdf_info(path),
  }

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdfviewer"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" }) -- mark loaded
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  local function st()
    return state[buf]
  end

  for _, k in ipairs({ "]", "<Space>", "<PageDown>", "n", "<Right>" }) do
    map(k, function() set_page(buf, st().page + 1) end)
  end
  for _, k in ipairs({ "[", "<BS>", "<PageUp>", "p", "<Left>" }) do
    map(k, function() set_page(buf, st().page - 1) end)
  end
  map("gg", function() set_page(buf, 1) end)
  map("G", function() set_page(buf, st().info.pages) end)

  map("+", function() set_zoom(buf, st().zoom * 1.25) end)
  map("=", function() set_zoom(buf, st().zoom * 1.25) end)
  map("-", function() set_zoom(buf, st().zoom / 1.25) end)
  map("0", function() set_zoom(buf, 1.0) end)

  local step = M.config.pan_step
  map("h", function() pan(buf, step, 0) end)
  map("l", function() pan(buf, -step, 0) end)
  map("k", function() pan(buf, 0, step) end)
  map("j", function() pan(buf, 0, -step) end)

  map("r", function() M.render(buf) end)
  map("q", function() vim.api.nvim_buf_delete(buf, { force = true }) end)

  local grp = vim.api.nvim_create_augroup("PdfViewer_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinResized", "VimResized" }, {
    group = grp,
    buffer = buf,
    callback = function()
      vim.schedule(function()
        apply_win_opts(buf)
        M.render(buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = grp,
    buffer = buf,
    callback = function()
      M.close(buf)
    end,
  })

  vim.schedule(function()
    apply_win_opts(buf)
    M.render(buf)
  end)
end

-- ---------------------------------------------------------------------------
-- setup
-- ---------------------------------------------------------------------------

-- launch the configured external PDF viewer and wipe the nvim buffer so we
-- don't sit on a stale, never-refreshing in-buffer render. Zathura watches the
-- file and auto-reloads on rebuild.
function M.open_external(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) == 0 then
    return
  end
  local cmd = vim.list_extend(vim.deepcopy(M.config.external_cmd), { path })
  local ok, err = pcall(vim.system, cmd, { detach = true })
  if not ok then
    vim.notify("pdf-viewer: failed to launch external viewer: " .. tostring(err),
      vim.log.levels.ERROR)
    return
  end
  -- drop the buffer so nvim doesn't show an empty/garbled PDF page
  vim.schedule(function()
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end)
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  local grp = vim.api.nvim_create_augroup("PdfViewer", { clear = true })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = grp,
    pattern = "*.pdf",
    callback = function(ev)
      if M.config.use_external then
        M.open_external(ev.buf)
      else
        M.open(ev.buf)
      end
    end,
  })
end

M.setup()

return M
