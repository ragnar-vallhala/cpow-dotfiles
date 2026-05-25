-- image.nvim: renders images in-terminal via the kitty graphics protocol.
-- `magick_cli` shells out to ImageMagick's `identify`/`convert`, so it works
-- with ImageMagick 6 (no luarocks / no `magick` v7 binary required).
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
  -- images stay reasonable. The PDF viewer sets `ignore_global_max_size` on its
  -- own images, so those caps never apply to PDF pages.
  window_overlapped_opacity = 0,
})
