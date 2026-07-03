return {
	"folke/todo-comments.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim"},
	config = function()
		local todo_comments = require("todo-comments")
		todo_comments.setup({
			keywords = {
				FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
				TODO = { icon = " ", color = "info", alt = {"Personal"} },
				HACK = { icon = " ", color = "warning", alt = { "DON SKIP" } },
				WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
				PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
				NOTE = { icon = " ", color = "hint", alt = { "INFO", "READ", "COLORS", "Custom" } },
				TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
				FORGETNOT = { icon = " ", color = "hint" },
			},
            highlight = {
                multiline = true, multiline_pattern = "^.", multiline_context = 10,
                before = "", keyword = "wide", after = "fg",
                pattern = { [[.*<(KEYWORDS)\s*:]], [[<!--\s*(KEYWORDS)\s*:.*-->]], [[<!--\s*(KEYWORDS)\s*.*-->]] },
                comments_only = false,
            },
            search = {
                command = "rg",
                args = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column" },
                pattern = [[\b(KEYWORDS)\b]],
            },
		})
		vim.keymap.set("n", "]t", function() todo_comments.jump_next() end, { desc = "Next todo comment" })
		vim.keymap.set("n", "[t", function() todo_comments.jump_prev() end, { desc = "Previous todo comment" })
	end,
}
