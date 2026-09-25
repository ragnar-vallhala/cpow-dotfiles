-- image.nvim: renders images in-terminal via the kitty graphics protocol.
-- `magick_cli` shells out to ImageMagick's `identify`/`convert`, so it works
-- with ImageMagick 6 (no luarocks / no `magick` v7 binary required).
-- Used for inline images in markdown buffers.
require("image").setup({
  backend = "kitty",
  processor = "magick_cli",
  integrations = {
    -- inline images while editing markdown (bonus, harmless)
    markdown = {
      enabled = true,
      only_render_image_at_cursor = false,
    },
  },
  -- Defaults left as-is (e.g. max_height_window_percentage = 50) so markdown
  -- images stay reasonable.
  window_overlapped_opacity = 0,
})
