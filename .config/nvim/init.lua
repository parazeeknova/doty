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
        dark0_hard = "#0f1512",
        dark0 = "#1b211e",
        dark1 = "#404944",
        dark2 = "#404944",
        dark3 = "#404944",
        dark4 = "#404944",
        light0 = "#dee4de",
        light1 = "#bfc9c2",
        light2 = "#bfc9c2",
        light3 = "#bfc9c2",
        light4 = "#bfc9c2",
        bright_red = "#ffb4ab",
        bright_green = "#8cd5b4",
        bright_yellow = "#a6ccdf",
        bright_blue = "#8cd5b4",
        bright_purple = "#b3ccbe",
        bright_aqua = "#b3ccbe",
        bright_orange = "#a6ccdf",
        neutral_red = "#ffb4ab",
        neutral_green = "#8cd5b4",
        neutral_yellow = "#a6ccdf",
        neutral_blue = "#8cd5b4",
        neutral_purple = "#b3ccbe",
        neutral_aqua = "#b3ccbe",
        neutral_orange = "#a6ccdf",
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
