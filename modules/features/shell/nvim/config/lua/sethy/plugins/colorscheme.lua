return {
    {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            require("rose-pine").setup({
                variant = "main",
                dark_variant = "main",
                dim_inactive_windows = false,
                styles = {
                    bold = true,
                    italic = false,
                    transparency = false,
                },
                enable = {
                    terminal = true,
                    legacy_highlights = true,
                    migrations = true,
                },
                highlight_groups = {
                    ColorColumn = { bg = "#1C1C21" },
                    NormalFloat = { bg = "#1C1C21" },
                    Pmenu = { bg = "#191724" },
                    PmenuSel = { bg = "#4a465d", fg = "NONE" },
                    FloatBorder = { bg = "base" },
                    FloatTitle = { bg = "base" },
                },
                groups = {
                    border = "muted",
                    link = "iris",
                    panel = "surface",
                    error = "love",
                    hint = "iris",
                    info = "foam",
                    note = "pine",
                    todo = "rose",
                    warn = "gold",
                    git_add = "foam",
                    git_change = "rose",
                    git_delete = "love",
                    git_dirty = "rose",
                    git_ignore = "muted",
                    git_merge = "iris",
                    git_rename = "pine",
                    git_stage = "iris",
                    git_text = "rose",
                    git_untracked = "subtle",
                    h1 = "iris",
                    h2 = "foam",
                    h3 = "rose",
                    h4 = "gold",
                    h5 = "pine",
                    h6 = "foam",
                },
            })
        end,
    },
    {
        "ellisonleao/gruvbox.nvim",
        config = function()
            require("gruvbox").setup({
                terminal_colors = true,
                undercurl = true,
                underline = true,
                bold = true,
                italic = {
                    strings = false,
                    emphasis = false,
                    comments = false,
                    folds = false,
                    operators = false,
                },
                strikethrough = true,
                invert_selection = false,
                invert_signs = false,
                invert_tabline = false,
                invert_intend_guides = false,
                inverse = true,
                contrast = "",
                palette_overrides = {},
                overrides = {
                    NormalFloat = { bg = "#282828" },
                    PmenuSel = { bg="#504945", fg = "NONE" },
                    Pmenu = { bg = "#1d2021" },
                },
                dim_inactive = false,
                transparent_mode = true,
            })
        end,
    },
    {
        "rebelot/kanagawa.nvim",
        config = function()
            require('kanagawa').setup({
                compile = false,
                undercurl = true,
                commentStyle = { italic = true },
                functionStyle = {},
                keywordStyle = { italic = false },
                statementStyle = { bold = true },
                typeStyle = {},
                transparent = true,
                dimInactive = false,
                terminalColors = true,
                colors = {
                    palette = {},
                    theme = {
                        wave = {},
                        dragon = {},
                        all = {
                            ui = {
                                bg_gutter = "none",
                                border = "rounded"
                            }
                        }
                    },
                },
                overrides = function(colors)
                    local theme = colors.theme
                    return {
                        FloatTitle = { bg = "none" },
                        Pmenu = { fg = theme.ui.shade0, bg = "NONE", blend = vim.o.pumblend },
                        PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
                        PmenuSbar = { bg = theme.ui.bg_m1 },
                        PmenuThumb = { bg = theme.ui.bg_p2 },
                        NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },
                        LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
                        MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
                        TelescopeTitle = { fg = theme.ui.special, bold = true },
                        TelescopePromptBorder = { fg = theme.ui.special, },
                        TelescopeResultsNormal = { fg = theme.ui.fg_dim, },
                        TelescopeResultsBorder = { fg = theme.ui.special, },
                        TelescopePreviewBorder = { fg = theme.ui.special },
                    }
                end,
                theme = "wave",
                background = {
                    dark = "wave",
                },
            })
        end
    },
    {
        "craftzdog/solarized-osaka.nvim",
        lazy = false,
        config = function()
            require("solarized-osaka").setup({
                transparent = true,
                terminal_colors = true,
                styles = {
                    comments = { italic = true },
                    keywords = { italic = false },
                    functions = {},
                    variables = {},
                    sidebars = "dark",
                    floats = "dark",
                },
                sidebars = { "qf", "help" },
                day_brightness = 0.3,
                hide_inactive_statusline = false,
                dim_inactive = false,
                lualine_bold = false,
                on_highlights = function(hl, c)
                    local prompt = "#2d3149"
                    hl.TelescopeNormal = { bg = c.bg_dark, fg = c.fg_dark }
                    hl.TelescopeBorder = { bg = c.bg_dark, fg = c.bg_dark }
                    hl.TelescopePromptNormal = { bg = c.bg_dark }
                    hl.TelescopePromptBorder = { bg = c.bg_dark, fg = c.bg_dark }
                    hl.TelescopePromptTitle = { bg = prompt, fg = "#2C94DD" }
                    hl.TelescopePreviewTitle = { bg = c.bg_dark, fg = c.bg_dark }
                    hl.TelescopeResultsTitle = { bg = c.bg_dark, fg = c.bg_dark }
                end,
            })
        end
    },
    {
        "folke/tokyonight.nvim",
        name = "folkeTokyonight",
        config = function()
            local transparent = true
            local bg = "#011628"
            local bg_dark = "#011423"
            local bg_highlight = "#143652"
            local bg_search = "#0A64AC"
            local bg_visual = "#275378"
            local fg = "#CBE0F0"
            local fg_dark = "#B4D0E9"
            local fg_gutter = "#627E97"
            local border = "#547998"

            require("tokyonight").setup({
                style = "night",
                transparent = transparent,
                styles = {
                    comments = { italic = false },
                    keywords = { italic = false },
                    sidebars = transparent and "transparent" or "dark",
                    floats = transparent and "transparent" or "dark",
                },
                on_colors = function(colors)
                    colors.bg = transparent and colors.none or bg
                    colors.bg_dark = transparent and colors.none or bg_dark
                    colors.bg_float = bg_dark
                    colors.bg_highlight = bg_highlight
                    colors.bg_popup = bg_dark
                    colors.bg_search = bg_search
                    colors.bg_sidebar = transparent and colors.none or bg_dark
                    colors.bg_statusline = transparent and colors.none or bg_dark
                    colors.bg_visual = bg_visual
                    colors.border = border
                    colors.fg = fg
                    colors.fg_dark = fg_dark
                    colors.fg_float = fg
                    colors.fg_gutter = fg_gutter
                    colors.fg_sidebar = fg_dark
                end,
            })
        end,
    },
    {
        "loctvl842/monokai-pro.nvim",
        config = function()
            require("monokai-pro").setup({
                transparent_background = true,
            })
        end
    },
    {
        "catppuccin/nvim",
        name = "catppuccin-nvim",
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                background = {
                    light = "latte",
                    dark = "mocha",
                },
                transparent_background = true,
                dim_inactive = {
                    enabled = false,
                    shade = "dark",
                    percentage = 0.15,
                },
                styles = {
                    comments = { "italic" },
                    conditionals = { "italic" },
                    loops = {},
                    functions = {},
                    keywords = { "bold" },
                    strings = {},
                    variables = {},
                    numbers = {},
                    booleans = {},
                    properties = {},
                    types = {},
                    operators = {},
                },
                custom_highlights = function(colors)
                    return {
                        ColorColumn = { bg = "#1C1C21" },
                        Pmenu = { bg = colors.transparent_background, fg = colors.text },
                        PmenuSel = { bg = colors.surface2, fg = "NONE" },
                        PmenuSbar = { bg = colors.surface0 },
                        PmenuThumb = { bg = colors.overlay2 },
                        NormalFloat = { bg = "none" },
                    }
                end,
                integrations = {
                    treesitter = true,
                    native_lsp = {
                        enabled = true,
                        virtual_text = { errors = { "italic" }, hints = { "italic" } },
                    },
                    lsp_trouble = true,
                    lsp_saga = true,
                    cmp = true,
                    telescope = true,
                    which_key = true,
                    gitsigns = true,
                    markdown = true,
                    mini = true,
                    dap = true,
                    dap_ui = true,
                },
            })
        end,
    },
}
