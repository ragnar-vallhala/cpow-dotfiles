-- Navigate vim panes better
vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')
vim.api.nvim_set_keymap('n', '<leader>ss', ':lua save_session()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')


