-- tokyonight: the default LazyVim look.
-- Styles: "moon" (default here), "storm", "night" (darkest), "day" (light).
require("tokyonight").setup({
  style = "moon",
  transparent = false, -- set true to see the terminal background through nvim
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
    sidebars = "dark", -- nvim-tree / oil panes sit slightly darker
    floats = "dark",
  },
})

-- catppuccin stays installed: `:colorscheme catppuccin` switches back anytime
require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = true,
  styles = {
    comments = { "italic" },
  },
})

vim.o.termguicolors = true
vim.o.background = "dark"
vim.cmd [[colorscheme tokyonight]]
