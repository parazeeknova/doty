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
        dark0_hard = "#12140e",
        dark0 = "#1e201a",
        dark1 = "#44483d",
        dark2 = "#44483d",
        dark3 = "#44483d",
        dark4 = "#44483d",
        light0 = "#e2e3d8",
        light1 = "#c5c8b9",
        light2 = "#c5c8b9",
        light3 = "#c5c8b9",
        light4 = "#c5c8b9",
        bright_red = "#ffb4ab",
        bright_green = "#b3d089",
        bright_yellow = "#a0d0cb",
        bright_blue = "#b3d089",
        bright_purple = "#c0cbac",
        bright_aqua = "#c0cbac",
        bright_orange = "#a0d0cb",
        neutral_red = "#ffb4ab",
        neutral_green = "#b3d089",
        neutral_yellow = "#a0d0cb",
        neutral_blue = "#b3d089",
        neutral_purple = "#c0cbac",
        neutral_aqua = "#c0cbac",
        neutral_orange = "#a0d0cb",
    },
    overrides = {},
    dim_inactive = true,
    transparent_mode = true
})

vim.cmd("colorscheme gruvbox")
