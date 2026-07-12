local theme_path = vim.fn.expand("~/.cache/matugen/nvim-theme.lua")
if vim.fn.filereadable(theme_path) == 1 then
    vim.cmd("source " .. theme_path)
    vim.cmd("doautocmd ColorScheme matugen")
else
    vim.cmd("colorscheme catppuccin")
end
