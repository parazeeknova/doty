return {
    {
        "saghen/blink.cmp",
        version = "v1.*",
        dependencies = {
            "L3MON4D3/LuaSnip",
            "rafamadriz/friendly-snippets",
        },
        config = function()
            require("blink.cmp").setup({
                fuzzy = { implementation = "prefer_rust" },
                keymap = {
                    preset = "default",
                    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                },
                completion = {
                    menu = { auto_show = true },
                    documentation = { auto_show = true },
                    ghost_text = { enabled = false, show_with_menu = false },
                    accept = { auto_brackets = { enabled = true } },
                },
                cmdline = {
                    enabled = true,
                    keymap = { preset = "cmdline" },
                    completion = { menu = { auto_show = true } },
                },
                sources = {
                    default = { "lsp", "path", "buffer", "snippets" },
                    providers = {
                        lsp = { opts = { tailwind_color_icon = "󱓻" } }
                    }
                },
                appearance = {
                    use_nvim_cmp_as_default = false,
                    nerd_font_variant = "mono",
                },
                snippets = { preset = "luasnip" },
            })
            require("luasnip.loaders.from_vscode").lazy_load()
            require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
        end,
    },
}
