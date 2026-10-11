-- diagram.nvim: renders ```mermaid``` (and plantuml/d2/gnuplot) fenced code
-- blocks inside markdown/neorg buffers as inline images via image.nvim.
--
-- Standalone *.mmd files are handled separately by mermaid_viewer.lua (which
-- keeps the source editable and shows a live preview split) -- diagram.nvim
-- only operates on document buffers, not on raw diagram files.
-- Share the mermaid_viewer's browser discovery + puppeteer config so
-- diagram.nvim's inline mmdc jobs also find Chrome and stay lightweight.
-- Without this, each block spawns a heavy scale=3 Chrome; on a machine
-- already under memory pressure that thrashes swap and freezes the system.
local mv = require("core.plugin_config.mermaid_viewer")

require("diagram").setup({
  integrations = {
    require("diagram.integrations.markdown"),
  },
  renderer_options = {
    mermaid = {
      theme = "forest",
      background = "transparent",
      scale = 2, -- supersample; 3 roughly doubles Chrome's memory per block
      -- pass the puppeteer config (--no-sandbox --disable-gpu
      -- --disable-dev-shm-usage) so headless Chrome renders cheaply
      cli_args = { "-p", mv.puppeteer_config() },
    },
  },
})
