-- image.nvim: renders images in-terminal via the kitty graphics protocol.
-- `magick_cli` shells out to ImageMagick's `identify`/`convert`, so it works
-- with ImageMagick 6 (no luarocks / no `magick` v7 binary required).

-- --- herdr inline-transmission shim -----------------------------------------
-- herdr relays the kitty graphics protocol (experimental.kitty_graphics = true
-- in ~/.config/herdr/config.toml) but INTERCEPTS the escapes and re-renders them
-- itself. So it can't read the local temp file image.nvim's kitty backend hands
-- over when it transmits by path (t=f) -- the image area just stays blank. The
-- backend only switches to inline/base64 transmission (which herdr *can*
-- consume) when it sees SSH_TTY/SSH_CLIENT at the moment its module first loads
-- (backends/kitty/init.lua: `is_SSH`). That module is lazy-loaded on first
-- render, so we export a sentinel SSH_TTY, force-load the backend now to capture
-- it, then restore the environment -- the shim never reaches nvim's children.
local _ssh_shim = vim.env.HERDR_ENV ~= nil
  and vim.env.SSH_TTY == nil
  and vim.env.SSH_CLIENT == nil
if _ssh_shim then
  vim.env.SSH_TTY = "herdr"
  require("image/backends/kitty") -- top-level captures is_SSH=true while shim is live
  vim.env.SSH_TTY = nil -- unset again; is_SSH is already captured for the session
end
-- ---------------------------------------------------------------------------

require("image").setup({
  backend = "kitty",
  processor = "magick_cli",
  -- Disable image.nvim's built-in file hijack (*.png/*.jpg/…). Our own
  -- image_file_viewer.lua owns image files instead: it fits to the window and
  -- adds zoom/pan (the native hijack has neither and is capped by
  -- max_height_window_percentage, so images render small/clipped). Leaving both
  -- on makes them fight over the buffer's filetype and double-place the image.
  hijack_file_patterns = {},
  -- TEMP: capture render failures to /tmp/image.nvim.log (remove once fixed)
  debug = { enabled = true, level = "debug", file_path = "/tmp/image.nvim.log", format = "compact" },
  integrations = {
    -- inline images while editing markdown (bonus, harmless)
    markdown = {
      enabled = true,
      only_render_image_at_cursor = false,
    },
  },
  -- Defaults left as-is (e.g. max_height_window_percentage = 50) so markdown
  -- images stay reasonable. The PDF viewer sets `ignore_global_max_size` on its
  -- own images, so those caps never apply to PDF pages.
  window_overlapped_opacity = 0,
})
