-- run tests in a :terminal split (vimux/tmux integration removed)
vim.cmd [[
  let test#strategy = "neovim"
  let test#neovim#term_position = "botright 15"
]]

vim.keymap.set('n', '<leader>t', ':TestNearest<CR>')
vim.keymap.set('n', '<leader>T', ':TestFile<CR>')
