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
        dark1 = "#50453a",
        dark2 = "#50453a",
        dark3 = "#50453a",
        dark4 = "#50453a",
        light0 = "#eee0d5",
        light1 = "#d4c4b5",
        light2 = "#d4c4b5",
        light3 = "#d4c4b5",
        light4 = "#d4c4b5",
        bright_red = "#ffb4ab",
        bright_green = "#f9ba72",
        bright_yellow = "#bccd9d",
        bright_blue = "#f9ba72",
        bright_purple = "#e0c1a2",
        bright_aqua = "#e0c1a2",
        bright_orange = "#bccd9d",
        neutral_red = "#ffb4ab",
        neutral_green = "#f9ba72",
        neutral_yellow = "#bccd9d",
        neutral_blue = "#f9ba72",
        neutral_purple = "#e0c1a2",
        neutral_aqua = "#e0c1a2",
        neutral_orange = "#bccd9d",
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
