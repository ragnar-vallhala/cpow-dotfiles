-- snacks.nvim provides the LazyVim start screen, indent guides, smooth
-- scrolling and the notification popups.
require("snacks").setup({
  bigfile = { enabled = true },    -- disable heavy features in huge files
  indent = { enabled = true },     -- indent guides + scope highlight
  input = { enabled = true },      -- pretty vim.ui.input
  notifier = { enabled = true, timeout = 3000 },
  quickfile = { enabled = true },  -- render the file before loading plugins
  scroll = { enabled = true },     -- smooth scrolling
  statuscolumn = { enabled = true },
  words = { enabled = true },      -- highlight the word under the cursor
  dashboard = {
    enabled = true,
    preset = {
      keys = {
        { icon = " ", key = "f", desc = "Find File", action = ":lua require('telescope.builtin').find_files()" },
        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        { icon = " ", key = "g", desc = "Find Text", action = ":lua require('telescope.builtin').live_grep()" },
        { icon = " ", key = "r", desc = "Recent Files", action = ":lua require('telescope.builtin').oldfiles()" },
        { icon = " ", key = "e", desc = "File Tree", action = ":NvimTreeToggle" },
        { icon = " ", key = "s", desc = "Restore Session", action = ":lua LoadSession()" },
        { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      },
    },
    sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    },
  },
})

-- route all notifications through the snacks notifier
vim.notify = require("snacks").notifier.notify
