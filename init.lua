-- Disable netrw (we’ll use nvim-tree or oil.nvim)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.cmd("set scrolloff=15")

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Session management
local function save_session()
  vim.cmd('mksession! mysession.vim')
  print("✅ Session saved as 'mysession.vim'")
end

local function load_session()
  local session_file = vim.fn.expand("%:p:h") .. "/mysession.vim"
  if vim.fn.filereadable(session_file) == 1 then
    vim.cmd('source ' .. session_file)
    print("✅ Session loaded from 'mysession.vim'")
  else
    print("⚠️ No session file found to load.")
  end
end

vim.keymap.set('n', '<leader>ss', save_session, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>ls', load_session, { noremap = true, silent = true })

-- Auto-load session if exists
local session_file = vim.fn.expand("%:p:h") .. "/mysession.vim"
if vim.fn.filereadable(session_file) == 1 then
  load_session()
end

-- Load custom config files
require("core.options")
require("core.keymaps")
require("core.plugins")
require("core.plugin_config")

