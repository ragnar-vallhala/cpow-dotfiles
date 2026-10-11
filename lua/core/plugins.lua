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
          "c", "cpp", "lua", "rust", "python",
          "html", -- leetcode.nvim renders problem descriptions with it
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
  -- renders mermaid/plantuml/d2 code blocks in markdown as images (via image.nvim)
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
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
          message = "",             -- save silently; no popup over the text
          cleaning_interval = 0,
        },
        trigger_events = { "InsertLeave", "TextChanged" }, -- Events that trigger auto-save
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
  -- Competitive programming: receives problems/testcases from the
  -- Competitive Companion browser extension and runs solutions locally.
  {
    "xeluxee/competitest.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    config = function()
      require("competitest").setup({
        -- How to compile / run each language
        compile_command = {
          cpp = { exec = "g++", args = { "-Wall", "-O2", "-std=c++17", "$(FNAME)", "-o", "$(FNOEXT)" } },
        },
        run_command = {
          cpp    = { exec = "./$(FNOEXT)" },
          python = { exec = "python3", args = { "$(FNAME)" } },
        },

        -- Starter templates used when a problem is received
        template_file = {
          cpp    = "~/.config/nvim/templates/template.cpp",
          python = "~/.config/nvim/templates/template.py",
        },
        evaluate_template_modifiers = true,

        -- Where received problems / contests land
        received_files_extension = "cpp",            -- default language for new files
        received_problems_path   = "$(CWD)/$(PROBLEM).$(FEXT)",
        received_contests_directory      = "$(CWD)/$(JUDGE)/$(CONTEST)",
        received_contests_problems_path  = "$(PROBLEM).$(FEXT)",
        open_received_problems = true,

        -- Testcase storage / UI
        testcases_directory = ".testcases",
        runner_ui = { interface = "popup" },
        companion_port = 27121,                       -- default Competitive Companion port
      })
    end,
  },

  -- LeetCode: full UI inside Neovim (browse, read, run tests, submit).
  {
    "kawre/leetcode.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",   -- problem picker
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      lang = "cpp",                       -- default language; switch per-problem with :Leet lang
      cn = { enabled = false },           -- leetcode.com (set true for leetcode.cn)
    },
  },

  -- Typr: MonkeyType-style typing practice in a floating window.
  -- Tracks WPM/accuracy and persists history + stats across sessions
  -- (data lives in stdpath("data")/typr/). :Typr to practice, :TyprStats for history.
  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    cmd = { "Typr", "TyprStats" },        -- lazy-load only when invoked
    opts = {},                            -- opts = {} makes lazy call typr.setup()
  },

})

-- Competitive programming keymaps (CompetiTest)
vim.keymap.set("n", "<leader>cp", "<cmd>CompetiTest receive problem<cr>",   { desc = "CP: receive a single Problem (creates file)" })
vim.keymap.set("n", "<leader>cr", "<cmd>CompetiTest run<cr>",               { desc = "CP: Run solution against samples" })
vim.keymap.set("n", "<leader>cC", "<cmd>CompetiTest receive contest<cr>",   { desc = "CP: receive a whole Contest" })
vim.keymap.set("n", "<leader>ct", "<cmd>CompetiTest receive testcases<cr>", { desc = "CP: receive Testcases for open file" })
vim.keymap.set("n", "<leader>cx", "<cmd>CompetiTest add_testcase<cr>",      { desc = "CP: add a testcase" })
vim.keymap.set("n", "<leader>ce", "<cmd>CompetiTest edit_testcase<cr>",     { desc = "CP: Edit a testcase" })

-- LeetCode keymaps (leetcode.nvim). Mirrors the Codeforces (<leader>c…) maps:
-- same second key = same action, only the first letter differs (c = Codeforces, l = LeetCode).
-- NOTE: <leader>ls is taken (load session), so submit uses <leader>lu.
vim.keymap.set("n", "<leader>lp", "<cmd>Leet<cr>",         { desc = "LeetCode: open Problem list / dashboard" })
vim.keymap.set("n", "<leader>lr", "<cmd>Leet run<cr>",     { desc = "LeetCode: Run / test current solution" })
vim.keymap.set("n", "<leader>lu", "<cmd>Leet submit<cr>",  { desc = "LeetCode: sUbmit solution" })
vim.keymap.set("n", "<leader>lc", "<cmd>Leet console<cr>", { desc = "LeetCode: open results Console" })
vim.keymap.set("n", "<leader>lL", "<cmd>Leet lang<cr>",    { desc = "LeetCode: switch Language" })

-- Typing practice keymaps (Typr). 'p' = Practice; 't' picks the Typing tool.
vim.keymap.set("n", "<leader>pt", "<cmd>Typr<cr>",        { desc = "Typr: typing Practice" })
vim.keymap.set("n", "<leader>pT", "<cmd>TyprStats<cr>",   { desc = "Typr: stats / history" })

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
