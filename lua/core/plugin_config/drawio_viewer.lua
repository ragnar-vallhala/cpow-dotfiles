-- ============================================================================
-- drawio_viewer.lua  --  open .drawio / .dio files in the drawio desktop app
--
-- draw.io files are XML you don't really hand-edit; you want the real editor.
-- This launches the drawio desktop app on the current file, detached, on your
-- real display. The buffer is written first so the app opens what you see.
--
-- (Use the .deb / AppImage drawio-desktop, not the snap -- the snap is
-- confined and can't read files under hidden dirs like ~/.config, and its
-- dialogs render as unreadable boxes.)
--
-- Commands / keymaps:
--   :DrawioOpen                open the current .drawio/.dio file in drawio
--   .drawio/.dio files : <leader>dd open in drawio
-- ============================================================================

local M = {}

function M.open(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if vim.fn.executable("drawio") == 0 then
    vim.notify("drawio: the drawio desktop app was not found in PATH", vim.log.levels.ERROR)
    return
  end

  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("drawio: save the buffer to a file first", vim.log.levels.WARN)
    return
  end

  -- flush pending edits so drawio opens the current content
  if vim.bo[buf].modified then
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
  end

  -- fire-and-forget: GUI app on the real display, not tied to this nvim
  local ok = pcall(vim.fn.jobstart, { "drawio", file }, { detach = true })
  if ok then
    vim.notify("drawio: opening " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
  else
    vim.notify("drawio: failed to launch the app", vim.log.levels.ERROR)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("DrawioOpen", function()
    M.open(vim.api.nvim_get_current_buf())
  end, { desc = "Open the current draw.io file in the drawio desktop app" })

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.drawio", "*.dio" },
    callback = function(ev)
      vim.bo[ev.buf].filetype = "xml" -- keep XML highlighting while editing
      vim.keymap.set("n", "<leader>dd", "<cmd>DrawioOpen<CR>",
        { buffer = ev.buf, desc = "Draw.io: open in desktop app" })
    end,
  })
end

M.setup()

return M
