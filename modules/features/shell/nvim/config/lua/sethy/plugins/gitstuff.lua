return {
	{
		"tpope/vim-fugitive",
        config = function()
            vim.keymap.set("n", "<leader>gg", "<cmd>tabnew | Git | only<cr>", { desc = "Fugitive fullscreen tab" })
            local myFugitive = vim.api.nvim_create_augroup("myFugitive", {})
            local autocmd = vim.api.nvim_create_autocmd
            autocmd("BufWinEnter", {
                group = myFugitive, pattern = "*",
                callback = function()
                    if vim.bo.ft ~= "fugitive" then return end
                    local bufnr = vim.api.nvim_get_current_buf()
                    local opts = {buffer = bufnr, remap = false}
                    vim.keymap.set("n", "<leader>P", function() vim.cmd.Git('push') end, opts)
                    vim.keymap.set("n", "<leader>p", function() vim.cmd.Git({'pull', '--rebase'}) end, opts)
                    vim.keymap.set("n", "<leader>t", ":Git push -u origin ", opts)
                end,
            })
        end,
    },
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns
				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end
				map("n", "]h", gs.next_hunk, "Next Hunk")
				map("n", "[h", gs.prev_hunk, "Prev Hunk")
				map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
				map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
				map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
				map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
				map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
				map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
				map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")
				map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
				map("n", "<leader>gbl", function() gs.blame_line({ full = true }) end, "Blame line")
				map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
				map("n", "<leader>gd", gs.diffthis, "Diff this")
				map("n", "<leader>gD", function() gs.diffthis("~") end, "Diff this ~")
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
			end,
		},
	},
    {
        "kdheepak/lazygit.nvim",
        enabled = false,
        cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = { { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open lazy git" } },
    },
    {
        "ThePrimeagen/git-worktree.nvim",
        dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
        config = function()
            local gitworktree = require("git-worktree")
            gitworktree.setup()
            require("telescope").load_extension("git_worktree")
            vim.keymap.set("n", "<leader>wl", function() require("telescope").extensions.git_worktree.git_worktrees() end, { desc = "list Git Worktree" })
            vim.keymap.set("n", "<leader>wc", function() require("telescope").extensions.git_worktree.create_git_worktree() end, { desc = "Create Git Worktree Branches" })
        end,
    }
}
