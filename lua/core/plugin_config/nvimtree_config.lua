require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = false, -- Show dotfiles by default
    git_ignored = false,
  },
})

-- Toggle nvim-tree and find the current file with <C-n>
vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>')
vim.keymap.set('n', '<C-f>', ':NvimTreeFindFile<CR>') -- Optionally add another shortcut to find files
