require("lazy").setup({
  { "catppuccin/nvim",      name = "catppuccin", priority = 1000 },
  "tpope/vim-commentary",
  "mattn/emmet-vim",
  "nvim-tree/nvim-tree.lua",
  "nvim-tree/nvim-web-devicons",
  "ellisonleao/gruvbox.nvim",
  "dracula/vim",
  "nvim-lualine/lualine.nvim",
  "nvim-treesitter/nvim-treesitter",
  "vim-test/vim-test",
  "lewis6991/gitsigns.nvim",
  "preservim/vimux",
  "christoomey/vim-tmux-navigator",
  "tpope/vim-fugitive",
  "tpope/vim-surround",
  "stevearc/oil.nvim",
  -- completion
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp",
  "L3MON4D3/LuaSnip",
  "saadparwaiz1/cmp_luasnip",
  "rafamadriz/friendly-snippets",
  "github/copilot.vim",
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",
  {
    "vinnymeller/swagger-preview.nvim",
    run = "npm install -g swagger-ui-watcher",
  },
  {
    "iamcco/markdown-preview.nvim",
    run = "cd app && npm install",
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
        enabled = true, -- Start with auto-save enabled
        execution_message = {
          message = function()
            return ("AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S"))
          end,
        },
        events = { "InsertLeave", "TextChanged" }, -- Events that trigger auto-save
        conditions = {
          exists = true,
          filename_is_not = {},
          filetype_is_not = {},
          modifiable = true,
        },
        clean_command_line_interval = 0, -- Delay after which autosave message clears
        write_all_buffers = false,       -- Write all buffers or just the current one
        debounce_delay = 135             -- Delay before auto-save triggers (in ms)
      })
    end
  },
  { "neovim/nvim-lspconfig" }, -- Ensure LSP support
  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")

      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.prettier,
          null_ls.builtins.formatting.clang_format,
        },
      })
    end
  },
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end
  },

})
