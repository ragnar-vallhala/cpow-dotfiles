-- noice moves the command line and search into floating windows and tidies
-- up LSP messages. Notifications themselves are handled by snacks.notifier.
require("noice").setup({
  lsp = {
    -- pyright re-analyses on every autosave; hide the "Analyzing…" spinner
    progress = { enabled = false },
    -- server popups (window/showMessage) go to the bottom-right corner too
    message = { view = "mini" },
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
    },
  },
  -- keep plain messages out of the way: small text in the bottom-right
  -- corner instead of popups over the code
  messages = { view = "mini", view_warn = "mini" },
  routes = {
    -- drop autosave / ":w" write messages entirely
    { filter = { event = "msg_show", find = "AutoSave" }, opts = { skip = true } },
    { filter = { event = "msg_show", find = "written" }, opts = { skip = true } },
    { filter = { event = "msg_show", find = "^%s*$" }, opts = { skip = true } },
    -- pyright info chatter ("Searching for source files", etc.)
    { filter = { event = "lsp", kind = "message", find = "[Pp]yright" }, opts = { skip = true } },
  },
  presets = {
    bottom_search = true,        -- classic bottom search bar
    command_palette = true,      -- cmdline and popupmenu together
    long_message_to_split = true,
    lsp_doc_border = true,
  },
})
