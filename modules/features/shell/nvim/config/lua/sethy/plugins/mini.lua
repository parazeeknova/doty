return {
    {"echasnovski/mini.nvim", version = false },
    {
        'echasnovski/mini.files',
        config = function()
            local MiniFiles = require("mini.files")
            MiniFiles.setup({ mappings = { go_in = "<CR>", go_in_plus = "L", go_out = "_", go_out_plus = "H" } })
            vim.keymap.set("n", "<leader>ee", "<cmd>lua MiniFiles.open()<CR>", { desc = "Toggle mini file explorer" })
            vim.keymap.set("n", "<leader>ef", function()
                MiniFiles.open(vim.api.nvim_buf_get_name(0), false)
                MiniFiles.reveal_cwd()
            end, { desc = "Toggle into currently opened file" })
        end,
    },
    {
        "echasnovski/mini.surround",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            custom_surroundings = nil,
            mappings = {
                add = 'sa', delete = 'ds', find = 'sf', find_left = 'sF',
                highlight = 'sh', replace = 'ca', update_n_lines = 'sn',
                suffix_last = 'l', suffix_next = 'n',
            },
        },
    },
    {
        "echasnovski/mini.trailspace",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local miniTrailspace = require("mini.trailspace")
            miniTrailspace.setup({ only_in_normal_buffers = true })
            vim.keymap.set("n", "<leader>cw", function() miniTrailspace.trim() end, { desc = "Erase Whitespace" })
            vim.api.nvim_create_autocmd("CursorMoved", {
                pattern = "*",
                callback = function() require("mini.trailspace").unhighlight() end,
            })
        end,
    },
    {
        "echasnovski/mini.splitjoin",
        config = function()
            local miniSplitJoin = require("mini.splitjoin")
            miniSplitJoin.setup({ mappings = { toggle = "" } })
            vim.keymap.set({ "n", "x" }, "sj", function() miniSplitJoin.join() end, { desc = "Join arguments" })
            vim.keymap.set({ "n", "x" }, "sk", function() miniSplitJoin.split() end, { desc = "Split arguments" })
        end,
    },
    {
        "echasnovski/mini.notify",
        config = function()
            require("mini.notify").setup({
                content = { format = function(notif) return notif.msg end },
                window = {
                    config = function()
                        return { title = "", anchor = "SE", row = vim.o.lines - 2, col = vim.o.columns, border = "none" }
                    end,
                },
            })
        end
    },
}
