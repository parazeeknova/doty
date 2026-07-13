return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local treesitter = require("nvim-treesitter")
            local ensure_installed = {
                "json", "javascript", "typescript", "tsx", "go", "yaml", "html", "css", "python",
                "http", "prisma", "svelte", "graphql", "bash", "vim", "dockerfile",
                "gitignore", "query", "vimdoc", "c", "cpp", "java", "rust", "ron",
            }
            treesitter.install(ensure_installed)
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "*",
                callback = function(args)
                    local buf = args.buf
                    local ft = vim.bo[buf].filetype
                    local lang = vim.treesitter.language.get_lang(ft)
                    if not lang then return end
                    pcall(vim.treesitter.start, buf, lang)
                    if ft ~= "yaml" and ft ~= "markdown" then
                        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                        vim.bo[buf].smartindent = false
                        vim.bo[buf].cindent = false
                    end
                end,
            })
        end,
    },
    {
        "windwp/nvim-ts-autotag",
        enabled = true,
        ft = { "html", "xml", "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte" },
        config = function()
            require("nvim-ts-autotag").setup({
                opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false },
                per_filetype = {
                    ["html"] = { enable_close = true },
                    ["typescriptreact"] = { enable_close = true },
                },
            })
        end,
    },
}
