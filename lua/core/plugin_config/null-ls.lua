local null = require("null-ls")

null.setup({
  sources = {
    -- JS/TS
    null.builtins.formatting.prettier,

    -- C/C++
    null.builtins.formatting.clang_format,

    -- Python
    null.builtins.formatting.black,

    -- Lua
    null.builtins.formatting.stylua,
  },
})

