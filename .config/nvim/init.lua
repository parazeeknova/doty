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
        dark0_hard = "#18120c",
        dark0 = "#251e17",
        dark1 = "#504539",
        dark2 = "#504539",
        dark3 = "#504539",
        dark4 = "#504539",
        light0 = "#eee0d4",
        light1 = "#d4c4b5",
        light2 = "#d4c4b5",
        light3 = "#d4c4b5",
        light4 = "#d4c4b5",
        bright_red = "#ffb4ab",
        bright_green = "#f8bb71",
        bright_yellow = "#bbcd9e",
        bright_blue = "#f8bb71",
        bright_purple = "#dfc2a2",
        bright_aqua = "#dfc2a2",
        bright_orange = "#bbcd9e",
        neutral_red = "#ffb4ab",
        neutral_green = "#f8bb71",
        neutral_yellow = "#bbcd9e",
        neutral_blue = "#f8bb71",
        neutral_purple = "#dfc2a2",
        neutral_aqua = "#dfc2a2",
        neutral_orange = "#bbcd9e",
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
