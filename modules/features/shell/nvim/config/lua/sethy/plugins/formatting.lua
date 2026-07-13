return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")
		conform.setup({
            formatters = {
                ["markdown-toc"] = {
                    condition = function(_, ctx)
                        for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
                            if line:find("<!%-%- toc %-%->") then return true end
                        end
                    end,
                },
                ["markdownlint-cli2"] = {
                    condition = function(_, ctx)
                        local diag = vim.tbl_filter(function(d) return d.source == "markdownlint" end, vim.diagnostic.get(ctx.buf))
                        return #diag > 0
                    end,
                },
            },
            formatters_by_ft = {
                c = { "clang-format" },
                cpp = { "clang-format" },
                javascript = { "biome-check" }, typescript = { "biome-check" },
                javascriptreact = { "biome-check" }, typescriptreact = { "biome-check" },
                css = { "biome-check" }, html = { "prettier" }, svelte = { "prettier" },
                json = { "biome-check" }, yaml = { "prettier" }, graphql = { "prettier" },
                liquid = { "prettier" }, lua = { "stylua" },
                markdown = { "mdformat","markdownlint-cli2","markdown-toc" },
            },
            format_on_save = function(bufnr)
                -- Disable with a global or buffer-local variable
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end
                return { timeout_ms = 500, lsp_fallback = true }
            end,
		})
		conform.formatters.prettier = {
			args = { "--stdin-filepath", "$FILENAME", "--tab-width", "4", "--use-tabs", "false" },
		}
		conform.formatters.shfmt = { prepend_args = { "-i", "4" } }
		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format({ lsp_fallback = true, async = false, timeout_ms = 1000 })
		end, { desc = "Format whole file or range in visual mode" })

        -- Toggle autoformat on save
        vim.api.nvim_create_user_command("FormatToggle", function(args)
            if args.bang then
                vim.g.disable_autoformat = not vim.g.disable_autoformat
                vim.notify("Global autoformat " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
            else
                vim.b.disable_autoformat = not vim.b.disable_autoformat
                vim.notify("Buffer autoformat " .. (vim.b.disable_autoformat and "disabled" or "enabled"))
            end
        end, {
            desc = "Toggle autoformat on save",
            bang = true,
        })

        vim.keymap.set("n", "<leader>uf", "<cmd>FormatToggle<CR>", { desc = "Toggle autoformat on save" })
	end,
}
