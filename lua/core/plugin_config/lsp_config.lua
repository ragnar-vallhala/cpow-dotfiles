-- Safe require Mason and Mason-LSPConfig
local mason_ok, mason = pcall(require, "mason")
local mason_lsp_ok, mason_lspconfig = pcall(require, "mason-lspconfig")

if mason_ok then mason.setup() end
if mason_lsp_ok then
  mason_lspconfig.setup({
    ensure_installed = { "lua_ls", "solargraph", "ts_ls", "gopls", "tailwindcss" },
    automatic_installation = true,
  })
end

-- Capabilities (for completion)
local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

-- Modern LSP setup using vim.lsp.config
local servers = {
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = {
          library = {
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.stdpath("config") .. "/lua"] = true,
          },
        },
      },
    },
  },
  solargraph = {},
  ts_ls = {},
  gopls = {},
  tailwindcss = {},
}

local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_ok then
  vim.notify("nvim-lspconfig not installed!", vim.log.levels.ERROR)
  return
end

for name, cfg in pairs(servers) do
  vim.lsp.config(name, vim.tbl_extend("force", { capabilities = capabilities }, cfg))
  vim.lsp.enable(name)
end





-- Keymaps on attach
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set("n", "<space>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  end,
})



-- Universal <space>f formatter
vim.keymap.set("n", "<space>f", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

  -- Filter clients that support formatting
  local formatting_clients = {}
  for _, client in ipairs(clients) do
    if client.supports_method("textDocument/formatting") then
      table.insert(formatting_clients, client)
    end
  end

  if #formatting_clients == 0 then
    vim.notify("No LSP attached that supports formatting", vim.log.levels.WARN)
    return
  end

  -- Choose preferred client for this buffer/filetype
  local ft = vim.bo[bufnr].filetype
  local preferred_client = nil

  local preferred_map = {
    c = "clangd",
    cpp = "clangd",
    lua = "lua_ls",
    python = "pyright", -- or pylsp if you prefer
    javascript = "ts_ls",
    typescript = "ts_ls",
    ruby = "solargraph",
  }

  for _, client in ipairs(formatting_clients) do
    if preferred_map[ft] and client.name == preferred_map[ft] then
      preferred_client = client
      break
    end
  end

  -- fallback to first available formatting client
  if not preferred_client then
    preferred_client = formatting_clients[1]
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = true,
    filter = function(client)
      return client.id == preferred_client.id
    end,
  })
end, { desc = "Format buffer using LSP or null-ls" })

