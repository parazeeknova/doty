return {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = true,
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown", "norg", "rmd", "org" },
    init = function()
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function() vim.treesitter.start() end,
        })
    end,
    opts = {
        restart_highlighter = true,
        heading = {
            sign = false,
            icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
            backgrounds = { "Headline1Bg", "Headline2Bg", "Headline3Bg", "Headline4Bg", "Headline5Bg", "Headline6Bg" },
            foregrounds = { "Headline1Fg", "Headline2Fg", "Headline3Fg", "Headline4Fg", "Headline5Fg", "Headline6Fg" },
        },
        code = { sign = false, width = "block", right_pad = 1 },
        bullet = { enabled = true },
        checkbox = {
            enabled = true,
            unchecked = { icon = "   󰄱 ", highlight = "RenderMarkdownUnchecked", scope_highlight = nil },
            checked = { icon = "   󰱒 ", highlight = "RenderMarkdownChecked", scope_highlight = nil },
        },
        html = { comment = { conceal = false } },
    },
}
