local ok, _ = pcall(require, 'vim._core.ui2')
if ok then
    require('vim._core.ui2').enable({
        enable = true,
        msg = {
            target = "cmd",
            pager = { height = 1 },
            msg   = { height = 0.5, timeout = 4500 },
            dialog = { height = 0.5 },
            cmd    = { height = 0.5 },
        },
    })
end

require("current-theme")
require("sethy.core")
require("sethy.lazy")
