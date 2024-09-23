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

-- Define session functions first
local function save_session()
    vim.api.nvim_command('mksession! mysession.vim')
    print("Session saved as 'mysession.vim'")
end

local function load_session()
    local session_file = vim.fn.expand("%:p:h") .. "/mysession.vim"
    if vim.fn.filereadable(session_file) == 1 then
        vim.api.nvim_command('source ' .. session_file)
        print("Session loaded from 'mysession.vim'")
    else
        print("No session file found to load.")
    end
end

-- Keybindings to save and load session
vim.api.nvim_set_keymap('n', '<leader>ss', ':lua save_session()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>ls', ':lua load_session()<CR>', { noremap = true, silent = true })

-- Automatically load session if "mysession.vim" exists
local session_file = vim.fn.expand("%:p:h") .. "/mysession.vim"
if vim.fn.filereadable(session_file) == 1 then
    load_session()  -- Call the function to load the session
end




local lspconfig = require('lspconfig')
lspconfig.pyright.setup{}
lspconfig.clangd.setup{}
require("nvim-tree").setup {
    filters = {
        dotfiles = true,  -- Set to true if you want to show dotfiles (files starting with .)
        git_ignored = true  -- Set to false to show files ignored by git
    },
}

require("core.options")
require("core.keymaps")
require("core.plugins")
require("core.plugin_config")
