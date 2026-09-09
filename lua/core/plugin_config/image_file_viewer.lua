-- ============================================================================
-- image_file_viewer.lua  --  open plain image files (png/jpg/…) in Neovim
--
-- Opening any image file renders it in-terminal (kitty graphics protocol, via
-- image.nvim) inside its own window, with zoom and pan. Without this, nvim
-- loads the file as binary and shows garbage; the PDF/mermaid/drawio viewers
-- each hook their own filetypes but nothing handled ordinary images.
--
-- This mirrors pdf_viewer.lua but is simpler: the file on disk already IS the
-- image, so there's no rasterisation or pagination -- we just fit/place it and
-- re-fit on zoom, pan and resize. `identify` (ImageMagick) supplies dimensions.
--
-- Keymaps inside an image buffer:
--   + (or =) / -  zoom in / out      0  reset zoom
--   h j k l       pan (when zoomed in past the window edges)
--   r             re-render
--   q             close the viewer
-- ============================================================================

local M = {}

local has_image, image_api = pcall(require, "image")

-- per-buffer state, keyed by bufnr
local state = {}

M.config = {
  -- extensions handled as viewable images
  extensions = { "png", "jpg", "jpeg", "gif", "webp", "bmp", "avif", "tiff", "ico" },
  -- terminal cell height:width ratio; used only for centering / initial fit.
  -- aspect ratio is never distorted (image.nvim preserves it).
  cell_ratio = 2.0,
  pan_step = 6,

  -- The in-terminal (kitty graphics) viewer only works when nvim talks straight
  -- to a graphics-capable terminal. Inside a multiplexer that doesn't relay the
  -- kitty protocol (herdr, tmux, …) NOTHING can draw -- so there we hand the
  -- image to an external GUI viewer in its own window instead (that window is
  -- outside the mux, so it renders fine). Same trade-off pdf_viewer.lua makes
  -- with zathura. `nil` = auto-detect the multiplexer at setup.
  use_external = nil,
  -- first available wins; overridable. Each gets the file path appended.
  external_candidates = {
    { "imv" }, { "swayimg" }, { "nsxiv" }, { "sxiv" },
    { "feh" }, { "eog" }, { "qimgv" }, { "gwenview" }, { "xdg-open" },
  },
  external_cmd = nil, -- set explicitly to skip auto-detection, e.g. { "feh" }
}

-- true when running inside a terminal multiplexer that can't pass the kitty
-- graphics protocol through to the real terminal.
--
-- herdr is NOT listed here: with `experimental.kitty_graphics = true` in
-- ~/.config/herdr/config.toml it relays the kitty protocol, so nvim can draw
-- inline and we want the in-terminal viewer, not feh. tmux/zellij stay blind
-- until their own passthrough is configured.
local function in_blind_mux()
  return vim.env.TMUX ~= nil or vim.env.ZELLIJ ~= nil
end

-- pick the first external viewer that exists on PATH
local function detect_external_cmd()
  if M.config.external_cmd then
    return M.config.external_cmd
  end
  for _, cmd in ipairs(M.config.external_candidates) do
    if vim.fn.executable(cmd[1]) == 1 then
      return cmd
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

-- pixel dimensions of the image; falls back to a square if `identify` fails.
local function get_image_info(path)
  local dims = vim.fn.systemlist({ "identify", "-format", "%w %h", path })[1] or ""
  local w, h = dims:match("(%d+)%s+(%d+)") -- first frame for animated formats
  return { w = tonumber(w) or 1, h = tonumber(h) or 1 }
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
    "  %s   %dx%d   %d%%   |  +/- zoom   0 reset   hjkl pan   q close ",
    name, st.info.w, st.info.h, math.floor(st.zoom * 100 + 0.5)
  )
  -- winbar is rendered as a statusline, where '%' introduces format items --
  -- escape every literal '%' (from the zoom percentage / any '%' in the name)
  -- to '%%' or nvim rejects the string with E539 and shows no winbar at all.
  text = text:gsub("%%", "%%%%")
  pcall(vim.api.nvim_set_option_value, "winbar", text, { win = win })
end

-- contain-fit the image inside its window, centered, scaled by the current zoom
local function compute_geometry(st, win)
  local win_w = vim.api.nvim_win_get_width(win)
  local win_h = vim.api.nvim_win_get_height(win)
  local avail_w = math.max(1, win_w - 4)
  local avail_h = math.max(1, win_h - 2)
  local aspect = st.info.w / st.info.h
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

  local x = math.floor((win_w - w) / 2) + (st.pan_x or 0)
  local y = math.floor((win_h - h) / 2) + (st.pan_y or 0)
  return { x = x, y = y, w = w, h = h, win_w = win_w, win_h = win_h }
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

  st.seq = (st.seq or 0) + 1
  if st.image then
    pcall(function() st.image:clear() end)
    st.image = nil
  end
  local ok, img = pcall(image_api.from_file, st.path, {
    id = "imgviewer_" .. buf .. "_" .. st.seq,
    window = win,
    buffer = buf,
    x = g.x,
    y = g.y,
    width = g.w,
    height = g.h,
  })
  if ok and img then
    -- bypass image.nvim's global caps (notably the default 50% window-height
    -- limit) -- the viewer sizes the image itself
    img.ignore_global_max_size = true
    st.image = img
    pcall(function() img:render() end)
  elseif not ok then
    vim.notify("image-viewer: " .. tostring(img), vim.log.levels.ERROR)
  end
  update_winbar(win, st)
end

-- ---------------------------------------------------------------------------
-- actions
-- ---------------------------------------------------------------------------

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
  pcall(vim.api.nvim_del_augroup_by_name, "ImageFileViewer_" .. buf)
  state[buf] = nil
end

-- ---------------------------------------------------------------------------
-- open
-- ---------------------------------------------------------------------------

function M.open(buf)
  if not has_image then
    vim.notify("image-viewer: image.nvim is not available", vim.log.levels.ERROR)
    return
  end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) == 0 then
    return
  end
  if state[buf] then
    M.close(buf) -- reopened with :e -- start fresh
  end

  state[buf] = {
    path = path,
    zoom = 1.0,
    pan_x = 0,
    pan_y = 0,
    info = get_image_info(path),
  }

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "imageviewer"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" }) -- mark loaded
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  local function st()
    return state[buf]
  end

  map("+", function() set_zoom(buf, st().zoom * 1.25) end)
  map("=", function() set_zoom(buf, st().zoom * 1.25) end)
  map("-", function() set_zoom(buf, st().zoom / 1.25) end)
  map("0", function() set_zoom(buf, 1.0) end)

  local step = M.config.pan_step
  map("h", function() pan(buf, step, 0) end)
  map("l", function() pan(buf, -step, 0) end)
  map("k", function() pan(buf, 0, step) end)
  map("j", function() pan(buf, 0, -step) end)
  map("<Left>", function() pan(buf, step, 0) end)
  map("<Right>", function() pan(buf, -step, 0) end)
  map("<Up>", function() pan(buf, 0, step) end)
  map("<Down>", function() pan(buf, 0, -step) end)

  map("r", function() M.render(buf) end)
  map("q", function() vim.api.nvim_buf_delete(buf, { force = true }) end)

  local grp = vim.api.nvim_create_augroup("ImageFileViewer_" .. buf, { clear = true })
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
-- external viewer (used when the terminal can't draw kitty graphics)
-- ---------------------------------------------------------------------------

-- launch the configured external image viewer in its own window and wipe the
-- nvim buffer so we don't sit on a garbled binary buffer.
function M.open_external(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) == 0 then
    return
  end
  local base = detect_external_cmd()
  if not base then
    vim.notify(
      "image-viewer: no external image viewer found (tried imv/feh/eog/xdg-open); "
        .. "install one or open this file in a graphics-capable terminal",
      vim.log.levels.ERROR
    )
    return
  end
  local cmd = vim.list_extend(vim.deepcopy(base), { path })
  local ok, err = pcall(vim.system, cmd, { detach = true })
  if not ok then
    vim.notify("image-viewer: failed to launch " .. base[1] .. ": " .. tostring(err),
      vim.log.levels.ERROR)
    return
  end
  -- drop the buffer so nvim doesn't show a binary blob
  vim.schedule(function()
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end)
end

-- ---------------------------------------------------------------------------
-- setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  -- decide in-terminal vs external once: inside a graphics-blind mux we can't
  -- draw, so default to launching an external viewer there.
  if M.config.use_external == nil then
    M.config.use_external = in_blind_mux()
  end

  -- the in-terminal viewer needs `identify` to size the image; without it, fall
  -- back to external so images still open somehow.
  if not M.config.use_external and vim.fn.executable("identify") == 0 then
    M.config.use_external = true
  end

  local grp = vim.api.nvim_create_augroup("ImageFileViewer", { clear = true })
  local patterns = {}
  for _, ext in ipairs(M.config.extensions) do
    patterns[#patterns + 1] = "*." .. ext
    patterns[#patterns + 1] = "*." .. ext:upper()
  end
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = grp,
    pattern = patterns,
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
