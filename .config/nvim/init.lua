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
        dark0_hard = "#19120c",
        dark0 = "#261e18",
        dark1 = "#50453a",
        dark2 = "#50453a",
        dark3 = "#50453a",
        dark4 = "#50453a",
        light0 = "#eee0d5",
        light1 = "#d5c3b5",
        light2 = "#d5c3b5",
        light3 = "#d5c3b5",
        light4 = "#d5c3b5",
        bright_red = "#ffb4ab",
        bright_green = "#fcb974",
        bright_yellow = "#bfcc9b",
        bright_blue = "#fcb974",
        bright_purple = "#e1c1a3",
        bright_aqua = "#e1c1a3",
        bright_orange = "#bfcc9b",
        neutral_red = "#ffb4ab",
        neutral_green = "#fcb974",
        neutral_yellow = "#bfcc9b",
        neutral_blue = "#fcb974",
        neutral_purple = "#e1c1a3",
        neutral_aqua = "#e1c1a3",
        neutral_orange = "#bfcc9b",
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
