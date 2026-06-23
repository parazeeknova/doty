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
        dark0_hard = "#131318",
        dark0 = "#1f1f25",
        dark1 = "#46464f",
        dark2 = "#46464f",
        dark3 = "#46464f",
        dark4 = "#46464f",
        light0 = "#e4e1e9",
        light1 = "#c7c5d0",
        light2 = "#c7c5d0",
        light3 = "#c7c5d0",
        light4 = "#c7c5d0",
        bright_red = "#ffb4ab",
        bright_green = "#bcc3ff",
        bright_yellow = "#e6bad7",
        bright_blue = "#bcc3ff",
        bright_purple = "#c4c5dd",
        bright_aqua = "#c4c5dd",
        bright_orange = "#e6bad7",
        neutral_red = "#ffb4ab",
        neutral_green = "#bcc3ff",
        neutral_yellow = "#e6bad7",
        neutral_blue = "#bcc3ff",
        neutral_purple = "#c4c5dd",
        neutral_aqua = "#c4c5dd",
        neutral_orange = "#e6bad7",
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
