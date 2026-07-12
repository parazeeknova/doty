return {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local lualine = require("lualine")
        local lazy_status = require("lazy.status")

        local function generate_theme()
            local function get_hl_color(group, attr)
                local hl = vim.api.nvim_get_hl(0, { name = group, link = true })
                local val = hl[attr]
                if not val then return nil end
                return string.format("#%06x", val)
            end

            -- Read dynamic theme colors from highlight groups
            local bg = get_hl_color("Normal", "bg") or "#11111B"
            local bg_dark = get_hl_color("StatusLine", "bg") or "#092236"
            local fg = get_hl_color("Normal", "fg") or "#c3ccdc"

            -- Mode colors mapped to theme accents
            local primary = get_hl_color("DiagnosticInfo", "fg") or "#828697"
            local secondary = get_hl_color("DiagnosticHint", "fg") or "#ae81ff"
            local tertiary = get_hl_color("DiagnosticWarn", "fg") or "#c3ccdc"
            local error_color = get_hl_color("DiagnosticError", "fg") or "#ff5874"
            local surface_variant = get_hl_color("Visual", "bg") or "#1c1e26"

            return {
                replace = {
                    a = { fg = bg, bg = error_color, gui = "bold" },
                    b = { fg = fg, bg = surface_variant },
                    c = { fg = fg, bg = bg_dark },
                    x = { fg = fg, bg = bg_dark },
                    y = { fg = fg, bg = surface_variant },
                    z = { fg = bg, bg = error_color },
                },
                inactive = {
                    a = { fg = fg, bg = bg_dark, gui = "bold" },
                    b = { fg = fg, bg = bg_dark },
                    c = { fg = fg, bg = bg_dark },
                    x = { fg = fg, bg = bg_dark },
                    y = { fg = fg, bg = bg_dark },
                    z = { fg = fg, bg = bg_dark },
                },
                normal = {
                    a = { fg = bg, bg = primary, gui = "bold" },
                    b = { fg = fg, bg = surface_variant },
                    c = { fg = fg, bg = bg_dark },
                    x = { fg = fg, bg = bg_dark },
                    y = { fg = fg, bg = surface_variant },
                    z = { fg = bg, bg = primary },
                },
                visual = {
                    a = { fg = bg, bg = secondary, gui = "bold" },
                    b = { fg = fg, bg = surface_variant },
                    c = { fg = fg, bg = bg_dark },
                    x = { fg = fg, bg = bg_dark },
                    y = { fg = fg, bg = surface_variant },
                    z = { fg = bg, bg = secondary },
                },
                insert = {
                    a = { fg = bg, bg = tertiary, gui = "bold" },
                    b = { fg = fg, bg = surface_variant },
                    c = { fg = fg, bg = bg_dark },
                    x = { fg = fg, bg = bg_dark },
                    y = { fg = fg, bg = surface_variant },
                    z = { fg = bg, bg = tertiary },
                },
            }
        end

        local mode = { 'mode', fmt = function(str) return '' .. str end }
        local diff = { 'diff', colored = true, symbols = { added = ' ', modified = ' ', removed = ' ' } }
        local filename = { 'filename', file_status = true, path = 0 }
        local branch = { 'branch', icon = { '', color = { fg = '#A6D4DE' } }, '|' }

        -- Setup lualine with the generated theme
        lualine.setup({
            icons_enabled = true,
            options = {
                theme = generate_theme(),
                component_separators = { left = "|", right = "|" },
                section_separators = { left = "|", right = "" }
            },
            sections = {
                lualine_a = { mode },
                lualine_b = { branch },
                lualine_c = { diff, filename },
                lualine_x = { { lazy_status.updates, cond = lazy_status.has_updates, color = { fg = "#ff9e64" } }, { "filetype" } },
            },
        })

        -- Re-generate theme whenever colorscheme changes
        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = function()
                lualine.setup({
                    options = { theme = generate_theme() }
                })
            end,
        })
    end,
}
