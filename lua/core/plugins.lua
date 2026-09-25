require("lazy").setup({
  { "catppuccin/nvim",      name = "catppuccin", priority = 1000 },
  { "folke/tokyonight.nvim", priority = 1000 },
  -- UI: dashboard, indent guides, scrolling, notifications
  { "folke/snacks.nvim",    priority = 900 },
  { "folke/which-key.nvim" },
  { "folke/noice.nvim",     dependencies = { "MunifTanjim/nui.nvim" } },
  "nvim-tree/nvim-tree.lua",
  "nvim-tree/nvim-web-devicons",
  "nvim-lualine/lualine.nvim",
  "vim-test/vim-test",
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c", "cpp", "lua", "rust", "python"
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
  "lewis6991/gitsigns.nvim",
  "tpope/vim-fugitive",
  "tpope/vim-surround",
  "stevearc/oil.nvim",
  -- completion
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp",
  "L3MON4D3/LuaSnip",
  "saadparwaiz1/cmp_luasnip",
  "rafamadriz/friendly-snippets",
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    -- these must be set before the plugin is sourced, or :MarkdownPreview is
    -- only defined in markdown buffers
    init = function()
      vim.g.mkdp_theme = "light"
      vim.g.mkdp_command_for_global = 1
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
  -- in-terminal image rendering (kitty graphics) -- inline markdown images
  {
    "3rd/image.nvim",
    build = false,
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.4",
    dependencies = { "nvim-lua/plenary.nvim" }
  },
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
    end
  },
  {
    "Pocco81/AutoSave.nvim",
    config = function()
      require("auto-save").setup({
        enabled = true,         -- Start with auto-save enabled
        execution_message = {
          message = function()
            return ("AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S"))
          end,
        },
        events = { "InsertLeave", "TextChanged" },         -- Events that trigger auto-save
        conditions = {
          exists = true,
          filename_is_not = {},
          filetype_is_not = {},
          modifiable = true,
        },
        clean_command_line_interval = 0,         -- Delay after which autosave message clears
        write_all_buffers = false,               -- Write all buffers or just the current one
        debounce_delay = 135                     -- Delay before auto-save triggers (in ms)
      })
    end
  },
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- sources are configured in core/plugin_config/null-ls.lua
  },
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end
  },

})

-- Custom key mappings
local api = require('Comment.api')

-- Normal mode
vim.keymap.set('n', '<C-.>', api.toggle.linewise.current)
vim.keymap.set('n', '<C-,>', api.toggle.blockwise.current)

-- Visual mode (use `gv` to reselect the visual area)
vim.keymap.set('v', '<C-.>', function()
  api.toggle.linewise(vim.fn.visualmode())
end)

vim.keymap.set('v', '<C-,>', function()
  api.toggle.blockwise(vim.fn.visualmode())
end)
