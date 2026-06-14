-- diagram.nvim: renders ```mermaid``` (and plantuml/d2/gnuplot) fenced code
-- blocks inside markdown/neorg buffers as inline images via image.nvim.
--
-- Standalone *.mmd files are handled separately by mermaid_viewer.lua (which
-- keeps the source editable and shows a live preview split) -- diagram.nvim
-- only operates on document buffers, not on raw diagram files.
require("diagram").setup({
  integrations = {
    require("diagram.integrations.markdown"),
  },
  renderer_options = {
    mermaid = {
      theme = "forest",
      background = "transparent",
      scale = 3, -- supersample so the kitty-graphics image stays crisp
    },
  },
})
