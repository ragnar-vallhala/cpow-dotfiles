-- noice moves the command line and search into floating windows and tidies
-- up LSP messages. Notifications themselves are handled by snacks.notifier.
require("noice").setup({
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
    },
  },
  presets = {
    bottom_search = true,        -- classic bottom search bar
    command_palette = true,      -- cmdline and popupmenu together
    long_message_to_split = true,
    lsp_doc_border = true,
  },
})
