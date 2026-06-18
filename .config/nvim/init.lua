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
        dark0_hard = "#11140e",
        dark0 = "#1d211a",
        dark1 = "#43483e",
        dark2 = "#43483e",
        dark3 = "#43483e",
        dark4 = "#43483e",
        light0 = "#e1e4d9",
        light1 = "#c4c8bb",
        light2 = "#c4c8bb",
        light3 = "#c4c8bb",
        light4 = "#c4c8bb",
        bright_red = "#ffb4ab",
        bright_green = "#abd28f",
        bright_yellow = "#a0cfcf",
        bright_blue = "#abd28f",
        bright_purple = "#bdcbaf",
        bright_aqua = "#bdcbaf",
        bright_orange = "#a0cfcf",
        neutral_red = "#ffb4ab",
        neutral_green = "#abd28f",
        neutral_yellow = "#a0cfcf",
        neutral_blue = "#abd28f",
        neutral_purple = "#bdcbaf",
        neutral_aqua = "#bdcbaf",
        neutral_orange = "#a0cfcf",
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
