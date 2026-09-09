-- Compatibility shim for nvim-treesitter (master branch, EOL) on Neovim 0.11+/0.12.
--
-- Neovim 0.12 removed the `all = false` option for query directives, so directive
-- handlers now always receive `match[capture_id]` as a *list* of TSNodes rather than
-- a single node. nvim-treesitter's frozen `master` branch still treats it as a single
-- node, so `vim.treesitter.get_node_text(node, ...)` is handed a list and crashes with
-- "attempt to call method 'range' (a nil value)" (e.g. when render-markdown parses
-- fenced code-block injections).
--
-- We re-register the affected directives with `force = true`, unwrapping the list to a
-- single node first. Harmless on older Neovim, where the value is already a node.

-- Ensure nvim-treesitter has registered its originals before we override them.
pcall(require, "nvim-treesitter.query_predicates")

local ok, query = pcall(require, "vim.treesitter.query")
if not ok then
  return
end

-- Newer Neovim hands directives a TSNode[]; older hands a single TSNode. Normalize.
local function node_of(value)
  if type(value) == "table" and value.range == nil then
    return value[#value]
  end
  return value
end

local html_script_type_languages = {
  ["importmap"] = "json",
  ["module"] = "javascript",
  ["application/ecmascript"] = "javascript",
  ["text/ecmascript"] = "javascript",
}

local non_filetype_match_injection_language_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  uxn = "uxntal",
  ts = "typescript",
}

local function get_parser_from_markdown_info_string(injection_alias)
  local match = vim.filetype.match({ filename = "a." .. injection_alias })
  return match or non_filetype_match_injection_language_aliases[injection_alias] or injection_alias
end

local opts = { force = true, all = false }

query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
  local node = node_of(match[pred[2]])
  if not node then
    return
  end
  local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
  local configured = html_script_type_languages[type_attr_value]
  if configured then
    metadata["injection.language"] = configured
  else
    local parts = vim.split(type_attr_value, "/", {})
    metadata["injection.language"] = parts[#parts]
  end
end, opts)

query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
  local node = node_of(match[pred[2]])
  if not node then
    return
  end
  local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
  metadata["injection.language"] = get_parser_from_markdown_info_string(injection_alias)
end, opts)

query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
  local id = pred[2]
  local node = node_of(match[id])
  if not node then
    return
  end
  local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
  if not metadata[id] then
    metadata[id] = {}
  end
  metadata[id].text = string.lower(text)
end, opts)
