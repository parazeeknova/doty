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
        dark0_hard = "#16130b",
        dark0 = "#231f17",
        dark1 = "#4c4639",
        dark2 = "#4c4639",
        dark3 = "#4c4639",
        dark4 = "#4c4639",
        light0 = "#eae1d4",
        light1 = "#cfc5b4",
        light2 = "#cfc5b4",
        light3 = "#cfc5b4",
        light4 = "#cfc5b4",
        bright_red = "#ffb4ab",
        bright_green = "#e4c36c",
        bright_yellow = "#adcfad",
        bright_blue = "#e4c36c",
        bright_purple = "#d5c5a0",
        bright_aqua = "#d5c5a0",
        bright_orange = "#adcfad",
        neutral_red = "#ffb4ab",
        neutral_green = "#e4c36c",
        neutral_yellow = "#adcfad",
        neutral_blue = "#e4c36c",
        neutral_purple = "#d5c5a0",
        neutral_aqua = "#d5c5a0",
        neutral_orange = "#adcfad",
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
