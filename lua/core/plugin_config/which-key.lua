-- popup showing what a pending key sequence can do
require("which-key").setup({
  preset = "helix",
  spec = {
    { "<leader>c", group = "code" },
    { "<leader>d", group = "debug/diagnostics" },
    { "<leader>f", group = "find" },
    { "<leader>m", group = "markdown" },
    { "<leader>s", group = "session" },
  },
})
