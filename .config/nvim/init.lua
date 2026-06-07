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
        dark0 = "#1d211a",
        dark1 = "#43483e",
        dark2 = "#43483e",
        dark3 = "#43483e",
        dark4 = "#43483e",
        light0 = "#e1e4d9",
        light1 = "#c3c8bb",
        light2 = "#c3c8bb",
        light3 = "#c3c8bb",
        light4 = "#c3c8bb",
        bright_red = "#ffb4ab",
        bright_green = "#a9d292",
        bright_yellow = "#a0cfd0",
        bright_blue = "#a9d292",
        bright_purple = "#bccbb0",
        bright_aqua = "#bccbb0",
        bright_orange = "#a0cfd0",
        neutral_red = "#ffb4ab",
        neutral_green = "#a9d292",
        neutral_yellow = "#a0cfd0",
        neutral_blue = "#a9d292",
        neutral_purple = "#bccbb0",
        neutral_aqua = "#bccbb0",
        neutral_orange = "#a0cfd0",
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
