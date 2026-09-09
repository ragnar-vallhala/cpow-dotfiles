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

-- Keep the LSP log from ballooning (it had grown to ~1GB).
-- Only record real errors instead of verbose debug/info traffic.
vim.lsp.log.set_level(vim.log.levels.ERROR)

--Line numbers
vim.wo.relativenumber = true
vim.wo.number = true

-- Soft wrap: break at word boundaries and indent continuation lines
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Yank -> system clipboard, no right-click needed.
-- Mirror every yank into the "+" register (which nvim backs with xclip,
-- bypassing herdr). Only the yank operator is mirrored, so d/x/c do NOT
-- clobber the system clipboard.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("yank_to_clipboard", { clear = true }),
  callback = function()
    local ev = vim.v.event
    if ev.operator == "y" and (ev.regname == "" or ev.regname == '"') then
      vim.fn.setreg("+", vim.fn.getreg('"'), vim.fn.getregtype('"'))
    end
  end,
})
