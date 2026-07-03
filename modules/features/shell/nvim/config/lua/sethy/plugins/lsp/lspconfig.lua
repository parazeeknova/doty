return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "saghen/blink.cmp",
        { "antosha417/nvim-lsp-file-operations", config = true },
    },
    config = function()
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
            callback = function(ev)
                local opts = { buffer = ev.buf, silent = true }
                opts.desc = "Show LSP references"
                vim.keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)
                opts.desc = "Go to declaration"
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                opts.desc = "Show LSP definitions"
                vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)
                opts.desc = "Show LSP implementations"
                vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
                opts.desc = "Show LSP type definitions"
                vim.keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)
                opts.desc = "See available code actions"
                vim.keymap.set({ "n", "v" }, "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
                opts.desc = "Smart rename"
                vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                opts.desc = "Show buffer diagnostics"
                vim.keymap.set("n", "<leader>D", function() require("snacks").picker.diagnostics_buffer() end, opts)
                opts.desc = "Show line diagnostics"
                vim.keymap.set("n", "df", function() vim.diagnostic.open_float() end, opts)
                opts.desc = "Show documentation for what is under cursor"
                vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                opts.desc = "Show signature help"
                vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
            end,
        })

        local signs = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = "󰠠 ",
            [vim.diagnostic.severity.INFO] = " ",
        }
        vim.diagnostic.config({
            signs = { text = signs }, virtual_text = true, underline = true,
            update_in_insert = false,
            float = { focusable = false, style = "minimal", border = "rounded", source = true },
        })

        vim.keymap.set("n", "<leader>lx", function()
            local current = vim.diagnostic.config().virtual_text
            vim.diagnostic.config({ virtual_text = not current })
        end, { desc = "Toggle LSP virtual text" })

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
        vim.lsp.config('*', { capabilities = capabilities })

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    diagnostics = { globals = { "vim" } },
                    completion = { callSnippet = "Replace" },
                    workspace = {
                        library = {
                            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                            [vim.fn.stdpath("config") .. "/lua"] = true,
                        },
                    },
                },
            },
        })

        vim.lsp.config("emmet_language_server", {
            filetypes = { "css", "html", "javascript", "javascriptreact", "less", "typescriptreact" },
            init_options = {
                includeLanguages = {}, excludeLanguages = {}, extensionsPath = {},
                preferences = {}, showAbbreviationSuggestions = true,
                showExpandedAbbreviation = "always", showSuggestionsAsSnippets = false,
                syntaxProfiles = {}, variables = {},
            },
        })

        vim.lsp.config("emmet_ls", {
            filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less", "svelte" },
        })

        vim.lsp.config("ts_ls", {
            filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
            single_file_support = true,
            init_options = {
                preferences = { includeCompletionsForModuleExports = true, includeCompletionsForImportStatements = true },
            },
            settings = {
                typescript = {
                    inlayHints = {
                        includeInlayParameterNameHints = "all",
                        includeInlayVariableTypeHints = true,
                        includeInlayFunctionParameterTypeHints = true,
                    },
                },
                javascript = {
                    validate = { enable = true },
                    inlayHints = { includeInlayParameterNameHints = "all", includeInlayVariableTypeHints = true },
                },
            },
        })

        vim.lsp.config("gopls", {
            settings = { gopls = { analyses = { unusedparams = true }, staticcheck = true, gofumpt = true } },
        })

        vim.lsp.config("cssls", {
          filetypes = { "css", "scss", "less" },
          init_options = { provideFormatter = true },
          single_file_support = true,
          settings = {
            css = { lint = { unknownAtRules = "ignore" }, validate = true },
            scss = { lint = { unknownAtRules = "ignore" }, validate = true },
            less = { lint = { unknownAtRules = "ignore" }, validate = true },
          },
        })

        vim.lsp.config("tailwindcss", {
            filetypes = { "html", "css", "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte", "vue", "astro" },
            init_options = { userLanguages = { astro = "html" } },
        })

        vim.lsp.config("astro", {
            filetypes = { "astro" },
            init_options = {
                typescript = { tsdk = vim.fn.stdpath("data") .. "/mason/packages/typescript-language-server/node_modules/typescript/lib" }
            },
        })

        vim.lsp.config("clangd", {
            cmd = { "clangd", "--background-index", "--clang-tidy" },
            filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
        })

        vim.lsp.config("nil_ls", {
            settings = {
                ["nil"] = {
                    formattingCommand = { "nixfmt" },
                    nix = {
                        flake = {
                            autoArchive = true,
                        },
                    },
                },
            },
        })

        vim.lsp.config("pyright", {
            settings = {
                python = {
                    analysis = {
                        typeCheckingMode = "basic",
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "openFilesOnly",
                    },
                },
            },
        })

        vim.lsp.config("elixirls", {
            cmd = { "elixir-ls" },
            settings = {
                elixirLS = {
                    dialyzerEnabled = true,
                    fetchDeps = false,
                    suggestSpecs = true,
                },
            },
        })

        vim.lsp.config("dockerls", {})

        vim.lsp.config("sqlls", {
            cmd = { "sql-language-server", "up", "--method", "stdio" },
        })

        vim.lsp.config("jsonls", {
            settings = {
                json = {
                    validate = { enable = true },
                },
            },
        })

        vim.lsp.config("jdtls", {
            cmd = { "jdtls" },
            filetypes = { "java" },
        })

        vim.lsp.enable({
            "lua_ls", "cssls", "emmet_language_server", "emmet_ls",
            "ts_ls", "gopls", "rust_analyzer", "astro", "tailwindcss", "marksman",
            "clangd", "nil_ls", "pyright", "elixirls", "dockerls", "sqlls", "jsonls", "jdtls",
        })
    end,
}
