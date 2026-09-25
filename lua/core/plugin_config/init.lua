-- Helper to safely require a module
local function safe_require(module)
  local ok, _ = pcall(require, module)
  if not ok then
    vim.notify("⚠️ Failed to load " .. module, vim.log.levels.WARN)
  end
end

-- ===============================
-- UI & Theme
-- ===============================
safe_require("core.plugin_config.colorscheme")
safe_require("core.plugin_config.snacks")
safe_require("core.plugin_config.lualine")
safe_require("core.plugin_config.which-key")
safe_require("core.plugin_config.noice")

-- ===============================
-- Syntax & Navigation
-- ===============================
safe_require("core.plugin_config.ts_compat") -- fix TS directives on Neovim 0.12
safe_require("core.plugin_config.telescope")

-- ===============================
-- Testing & Completions
-- ===============================
safe_require("core.plugin_config.vim-test")
safe_require("core.plugin_config.completions")

-- ===============================
-- LSP & Mason
-- ===============================
safe_require("core.plugin_config.mason")
safe_require("core.plugin_config.lsp_config")
safe_require("core.plugin_config.null-ls")

-- ===============================
-- Git
-- ===============================
safe_require("core.plugin_config.gitsigns")

-- ===============================
-- File explorers & Previews
-- ===============================
safe_require("core.plugin_config.oil")
safe_require("core.plugin_config.nvimtree_config")
safe_require("core.plugin_config.render_markdown")
safe_require("core.plugin_config.image")
