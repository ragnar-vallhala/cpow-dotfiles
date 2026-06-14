-- ============================================================================
-- mermaid_viewer.lua  --  zoomable mermaid preview
--
-- A thin mermaid adapter on top of image_viewer.lua (the generic zoom/pan
-- engine). This file owns only what is mermaid-specific: rendering source with
-- `mmdc`, pulling ```mermaid``` blocks out of markdown, and the .mmd filetype.
-- Two entry points:
--
--   * standalone *.mmd / *.mermaid files  -- the file stays an editable text
--     buffer; the preview tracks the whole buffer and re-renders on save/edit.
--
--   * a ```mermaid``` block inside markdown -- pops the block under the cursor
--     into the same zoom viewer. (The inline render from diagram.nvim is fixed
--     to text size and can't zoom; this is how you blow one up.)
--
-- Commands / keymaps:
--   :MermaidPreview        preview current .mmd file OR the block under cursor
--   :MermaidPreviewClose   close the preview for this buffer
--   .mmd files     : <leader>mm preview   <leader>mc close
--   markdown files : <leader>mm zoom the mermaid block under the cursor
--   inside the preview window:  + / - zoom   0 reset   h/j/k/l pan
--                               r re-render   q close
-- ============================================================================

local V = require("core.plugin_config.image_viewer")

local M = {}

M.config = {
  theme = "forest",
  background = "transparent",
  scale = 3, -- supersample for crisp kitty-graphics output
  split_width = 0.5,
  cell_ratio = 2.0,
  pan_step = 4,
}

-- ---------------------------------------------------------------------------
-- markdown block extraction (treesitter)
-- ---------------------------------------------------------------------------

local md_query
local function get_md_query()
  if not md_query then
    md_query = vim.treesitter.query.parse(
      "markdown",
      "(fenced_code_block (info_string) @info (code_fence_content) @code)"
    )
  end
  return md_query
end

-- find the ```mermaid``` block whose range contains `row` (0-indexed); pass
-- row=nil for "the first mermaid block". Returns { source, start_row } or nil.
local function mermaid_block_at(buf, row)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return nil
  end
  parser:parse(true)
  local root = parser:parse()[1]:root()
  local q = get_md_query()
  local info
  for id, node in q:iter_captures(root, buf) do
    local cap = q.captures[id]
    if cap == "info" then
      info = vim.treesitter.get_node_text(node, buf)
    elseif cap == "code" then
      if info and info:match("^mermaid") then
        local block = node:parent()
        local sr, _, er = block:range()
        if row == nil or (row >= sr and row <= er) then
          return { source = vim.treesitter.get_node_text(node, buf), start_row = sr }
        end
      end
      info = nil
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- rendering: source text -> png via mmdc (cached by content hash)
-- ---------------------------------------------------------------------------

local function render_png(st, source, cb)
  if not source or source:match("^%s*$") then
    return cb(nil) -- nothing to render (empty buffer / block went away)
  end
  local hash = vim.fn.sha256(M.config.theme .. M.config.scale .. source)
  local png = st.tmp .. "/" .. hash .. ".png"
  if vim.fn.filereadable(png) == 1 then
    return cb(png)
  end

  local src = st.tmp .. "/src.mmd"
  vim.fn.writefile(vim.split(source, "\n"), src)

  vim.system({
    "mmdc",
    "-i", src,
    "-o", png,
    "-t", M.config.theme,
    "-b", M.config.background,
    "-s", tostring(M.config.scale),
  }, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 and vim.fn.filereadable(png) == 1 then
        cb(png)
      else
        cb(nil, "render failed\n" .. ((res.stderr ~= "" and res.stderr) or (res.stdout or "unknown error")))
      end
    end)
  end)
end

-- build the engine opts shared by both entry points
local function viewer_opts(key, src_buf, source_fn)
  return {
    key = key,
    src_buf = src_buf,
    name = "mermaid",
    winbar = "  mermaid   +/- zoom  0 reset  hjkl/arrows pan  r redraw  q close ",
    split_width = M.config.split_width,
    cell_ratio = M.config.cell_ratio,
    pan_step = M.config.pan_step,
    watch_events = { "BufWritePost", "TextChanged", "InsertLeave" },
    render = function(st, cb) render_png(st, source_fn(), cb) end,
  }
end

-- ---------------------------------------------------------------------------
-- public entry points
-- ---------------------------------------------------------------------------

-- preview a whole .mmd / .mermaid buffer (whole-buffer source)
function M.open_file(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.fn.executable("mmdc") == 0 then
    vim.notify("mermaid: mmdc (mermaid-cli) not found in PATH", vim.log.levels.ERROR)
    return
  end
  V.open(viewer_opts("file:" .. buf, buf, function()
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  end))
end

-- zoom the ```mermaid``` block under the cursor in a markdown buffer. One
-- preview per markdown buffer -- invoking it on a different block re-points
-- the same window at that block. The block is tracked by an extmark so it
-- survives edits above it.
function M.open_block(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.fn.executable("mmdc") == 0 then
    vim.notify("mermaid: mmdc (mermaid-cli) not found in PATH", vim.log.levels.ERROR)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local blk = mermaid_block_at(buf, row) or mermaid_block_at(buf, nil)
  if not blk then
    vim.notify("mermaid: no mermaid block under the cursor", vim.log.levels.WARN)
    return
  end

  local key = "mdblock:" .. buf
  V.open(viewer_opts(key, buf, function()
    local st = V.state[key]
    if not (st and st.mark) then
      return nil
    end
    local pos = vim.api.nvim_buf_get_extmark_by_id(buf, st.ns, st.mark, {})
    if not pos or not pos[1] then
      return nil
    end
    local b = mermaid_block_at(buf, pos[1])
    return b and b.source or nil
  end))

  -- (re)anchor the tracking extmark to the chosen block, then redraw
  local st = V.state[key]
  if st then
    st.ns = st.ns or vim.api.nvim_create_namespace("mermaid_block")
    if st.mark then
      pcall(vim.api.nvim_buf_del_extmark, buf, st.ns, st.mark)
    end
    st.mark = vim.api.nvim_buf_set_extmark(buf, st.ns, blk.start_row, 0, {})
    V.render(key)
  end
end

-- filetype-aware dispatch for the :MermaidPreview command
function M.preview(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "mermaid" then
    M.open_file(buf)
  else
    M.open_block(buf)
  end
end

function M.close_for_buf(buf)
  V.close_for_buf(buf or vim.api.nvim_get_current_buf())
end

-- ---------------------------------------------------------------------------
-- setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  -- standalone mermaid files get their own filetype (editable text buffer)
  vim.filetype.add({ extension = { mmd = "mermaid", mermaid = "mermaid" } })

  vim.api.nvim_create_user_command("MermaidPreview", function()
    M.preview(vim.api.nvim_get_current_buf())
  end, { desc = "Preview the current mermaid file / block under cursor" })

  vim.api.nvim_create_user_command("MermaidPreviewClose", function()
    M.close_for_buf(vim.api.nvim_get_current_buf())
  end, { desc = "Close the mermaid preview for this buffer" })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "mermaid", "markdown" },
    callback = function(ev)
      vim.keymap.set("n", "<leader>mm", "<cmd>MermaidPreview<CR>",
        { buffer = ev.buf, desc = "Mermaid: zoomable preview" })
      vim.keymap.set("n", "<leader>mc", "<cmd>MermaidPreviewClose<CR>",
        { buffer = ev.buf, desc = "Mermaid: close preview" })
    end,
  })
end

M.setup()

return M
