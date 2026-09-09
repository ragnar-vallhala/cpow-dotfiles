vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

-- use spaces for tabs and whatnot
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.shiftround = true
vim.opt.expandtab = true

vim.cmd [[ set noswapfile ]]
vim.cmd [[ set termguicolors ]]

--Line numbers
vim.wo.relativenumber = true
vim.wo.number = true

-- Soft wrap: break at word boundaries and indent continuation lines
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Share the unnamed register with the system clipboard, so y/p work across apps
vim.opt.clipboard = 'unnamedplus'

-- Briefly highlight yanked text, so it is obvious what went to the clipboard
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight_yank', { clear = true }),
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})
