return {
    "windwp/nvim-autopairs",
    event = { "InsertEnter" },
    config = function()
        local autopairs = require("nvim-autopairs")
        autopairs.setup({
            enable_afterquote = false, check_ts = true,
            ts_config = {
                lua = { "string" },
                java = false,
            },
        })
    end,
}
