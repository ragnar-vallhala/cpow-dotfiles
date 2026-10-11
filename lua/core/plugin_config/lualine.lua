-- Word count for the buffer, or for the selection while in visual mode
local function word_count()
  local wc = vim.fn.wordcount()
  if wc.visual_words then
    return wc.visual_words .. '/' .. wc.words .. ' words'
  end
  return wc.words .. ' words'
end

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'tokyonight',
    globalstatus = true, -- one statusline for the whole window layout
    section_separators = { left = '', right = '' },
    component_separators = { left = '', right = '' },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch' },
    lualine_c = {
      { 'diagnostics', symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' } },
      { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
      { 'filename', path = 1 },
    },
    lualine_x = {
      { 'diff', symbols = { added = ' ', modified = ' ', removed = ' ' } },
      word_count,
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
}
