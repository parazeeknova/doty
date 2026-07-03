return {
    "mason-org/mason.nvim",
    lazy = false,
    dependencies = {
        "mason-org/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        "neovim/nvim-lspconfig",
    },
    config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        local mason_tool_installer = require("mason-tool-installer")

        mason.setup({
            ui = { icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" } },
        })

        mason_lspconfig.setup({
            automatic_enable = false,
            ensure_installed = {
                "lua_ls", "ts_ls", "html", "cssls", "tailwindcss",
                "gopls", "angularls", "astro", "emmet_ls", "emmet_language_server", "marksman",
                "clangd", "nil_ls", "pyright", "elixirls", "dockerls", "sqlls", "jsonls", "jdtls",
            },
        })

        mason_tool_installer.setup({
            ensure_installed = { "biome", "prettier", "stylua", "isort", "pylint", "clangd", "denols" },
        })
    end,
}
