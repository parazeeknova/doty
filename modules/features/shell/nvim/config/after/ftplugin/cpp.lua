local set = vim.opt_local

set.tabstop = 2
set.shiftwidth = 2
set.softtabstop = 2
set.expandtab = true

-- Insert competitive programming boilerplate
vim.keymap.set("n", "<leader>cp", function()
    local boilerplate = {
        "#include <bits/stdc++.h>",
        "using namespace std;",
        "",
        "#if 1",
        "int main() {",
        "  ios::sync_with_stdio(false);",
        "  cin.tie(nullptr);",
        "",
        "  ",
        "  return 0;",
        "}",
        "#endif"
    }

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_empty = #lines == 1 and lines[1] == ""

    if is_empty then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, boilerplate)
        vim.api.nvim_win_set_cursor(0, { 9, 2 })
    else
        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, boilerplate)
        vim.api.nvim_win_set_cursor(0, { row + 8, 2 })
    end
    vim.cmd("startinsert")
end, { buffer = true, desc = "Insert C++ CP boilerplate" })
