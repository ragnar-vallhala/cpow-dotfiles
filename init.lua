vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


-- Function to save session
local function save_session()
    vim.api.nvim_command('mksession! mysession.vim')
    print("Session saved as 'mysession.vim'")
end

-- Function to load session
local function load_session()
    vim.api.nvim_command('source mysession.vim')
    print("Session loaded from 'mysession.vim'")
end

-- Keybindings to save and load session
vim.api.nvim_set_keymap('n', '<leader>ss', ':lua save_session()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>ls', ':lua load_session()<CR>', { noremap = true, silent = true })

-- Automatically load session if "mysession.vim" exists
local session_file = 'mysession.vim'
if vim.fn.filereadable(session_file) == 1 then
    vim.api.nvim_command('source ' .. session_file)
    print("Session loaded automatically from 'mysession.vim'")
end


require("core.options")
require("core.keymaps")
require("core.plugins")
require("core.plugin_config")
