require("render-markdown").setup({
  -- Render only in normal mode / when not actively editing the line
  render_modes = { "n", "c", "t" },
  heading = {
    sign = true,
    icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
  },
  code = {
    style = "full",
    border = "thin",
  },
  checkbox = {
    enabled = true,
    unchecked = { icon = "󰄱 " },
    checked = { icon = "󰱒 " },
  },
})

-- Toggle in-buffer rendering on/off
vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>",
  { desc = "Toggle markdown rendering" })
