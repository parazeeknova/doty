-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Default options:
require("gruvbox").setup({
    terminal_colors = true,
    undercurl = true,
    underline = true,
    bold = true,
    italic = {
        strings = true,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true
    },
    strikethrough = true,
    invert_selection = false,
    invert_signs = false,
    invert_tabline = false,
    inverse = true,
    contrast = "hard",
    palette_overrides = {
        dark0_hard = "#141318",
        dark0 = "#201f24",
        dark1 = "#48454e",
        dark2 = "#48454e",
        dark3 = "#48454e",
        dark4 = "#48454e",
        light0 = "#e6e1e9",
        light1 = "#c9c4d0",
        light2 = "#c9c4d0",
        light3 = "#c9c4d0",
        light4 = "#c9c4d0",
        bright_red = "#ffb4ab",
        bright_green = "#cbbeff",
        bright_yellow = "#eeb8cb",
        bright_blue = "#cbbeff",
        bright_purple = "#cac3dc",
        bright_aqua = "#cac3dc",
        bright_orange = "#eeb8cb",
        neutral_red = "#ffb4ab",
        neutral_green = "#cbbeff",
        neutral_yellow = "#eeb8cb",
        neutral_blue = "#cbbeff",
        neutral_purple = "#cac3dc",
        neutral_aqua = "#cac3dc",
        neutral_orange = "#eeb8cb",
    },
    overrides = {
        NormalFloat = { bg = "NONE" },
        FloatBorder = { bg = "NONE" },
        FloatTitle = { bg = "NONE" },
    },
    dim_inactive = true,
    transparent_mode = true
})

vim.cmd("colorscheme gruvbox")
