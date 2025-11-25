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
safe_require("core.plugin_config.lualine")

-- ===============================
-- Syntax & Navigation
-- ===============================
safe_require("core.plugin_config.treesitter")
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
-- Git & AI
-- ===============================
safe_require("core.plugin_config.gitsigns")
safe_require("core.plugin_config.copilot")

-- ===============================
-- File explorers & Previews
-- ===============================
safe_require("core.plugin_config.oil")
safe_require("core.plugin_config.nvimtree_config")
safe_require("core.plugin_config.markdown_preview")
safe_require("core.plugin_config.swagger-preview")

