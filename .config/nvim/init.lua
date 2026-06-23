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
        dark0_hard = "#1d2021",
        dark0 = "#282828",
        dark1 = "#3c3836",
        dark2 = "#3c3836",
        dark3 = "#3c3836",
        dark4 = "#3c3836",
        light0 = "#ebdbb2",
        light1 = "#d5c4a1",
        light2 = "#d5c4a1",
        light3 = "#d5c4a1",
        light4 = "#d5c4a1",
        bright_red = "#cc241d",
        bright_green = "#a9b665",
        bright_yellow = "#d8a657",
        bright_blue = "#a9b665",
        bright_purple = "#7daea3",
        bright_aqua = "#7daea3",
        bright_orange = "#d8a657",
        neutral_red = "#cc241d",
        neutral_green = "#a9b665",
        neutral_yellow = "#d8a657",
        neutral_blue = "#a9b665",
        neutral_purple = "#7daea3",
        neutral_aqua = "#7daea3",
        neutral_orange = "#d8a657",
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
