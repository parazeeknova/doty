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
        dark0_hard = "#11140f",
        dark0 = "#1d211b",
        dark1 = "#42493f",
        dark2 = "#42493f",
        dark3 = "#42493f",
        dark4 = "#42493f",
        light0 = "#e0e4da",
        light1 = "#c2c8bc",
        light2 = "#c2c8bc",
        light3 = "#c2c8bc",
        light4 = "#c2c8bc",
        bright_red = "#ffb4ab",
        bright_green = "#a4d397",
        bright_yellow = "#a0cfd3",
        bright_blue = "#a4d397",
        bright_purple = "#bbccb2",
        bright_aqua = "#bbccb2",
        bright_orange = "#a0cfd3",
        neutral_red = "#ffb4ab",
        neutral_green = "#a4d397",
        neutral_yellow = "#a0cfd3",
        neutral_blue = "#a4d397",
        neutral_purple = "#bbccb2",
        neutral_aqua = "#bbccb2",
        neutral_orange = "#a0cfd3",
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
