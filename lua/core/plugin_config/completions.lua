local cmp = require("cmp")
local luasnip = require("luasnip")

-- Set up luasnip
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-o>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
    { name = 'path' },
  }),
})

-- Add key mappings for Code Companion
local api = require('Comment.api')

-- Normal mode
vim.keymap.set('n', '<C-.>', api.toggle.linewise.current)
vim.keymap.set('n', '<C-,>', api.toggle.blockwise.current)

-- Visual mode (use `gv` to reselect the visual area)
vim.keymap.set('v', '<C-.>', function()
  api.toggle.linewise(vim.fn.visualmode())
end)

vim.keymap.set('v', '<C-,>', function()
  api.toggle.blockwise(vim.fn.visualmode())
end)

-- Code Companion key mappings
vim.keymap.set('n', '<Leader>cc', require("codecompanion").toggle)
vim.keymap.set('n', '<Leader>ca', require("codecompanion").action)

-- Custom command to toggle and perform action with Code Companion
vim.api.nvim_create_user_command('CodeCompanionToggleAction', function()
  vim.cmd('<Leader>cc')
  vim.cmd('<Leader>ca')
end, {})

return {
  setup = cmp.setup,
}
