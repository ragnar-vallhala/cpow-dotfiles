-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw (we’ll use nvim-tree or oil.nvim)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.cmd("set scrolloff=15")

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
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

-- Session management (always relative to the current working directory)
local function session_path()
  return vim.fn.getcwd() .. "/mysession.vim"
end

local function save_session()
  vim.cmd("mksession! " .. vim.fn.fnameescape(session_path()))
  print("✅ Session saved as 'mysession.vim'")
end

local function load_session()
  local session_file = session_path()
  if vim.fn.filereadable(session_file) == 1 then
    vim.cmd("source " .. vim.fn.fnameescape(session_file))
    print("✅ Session loaded from 'mysession.vim'")
  else
    print("⚠️ No session file found to load.")
  end
end

-- exposed globally so the dashboard's "Restore Session" entry can call it
_G.LoadSession = load_session
_G.SaveSession = save_session

vim.keymap.set('n', '<leader>ss', save_session, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>ls', load_session, { noremap = true, silent = true })

-- Load custom config files
require("core.options")
require("core.keymaps")
require("core.plugins")
require("core.plugin_config")

-- Auto-load a session for this directory, once plugins are configured
vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.filereadable(session_path()) == 1 then
      load_session()
    end
  end,
})
