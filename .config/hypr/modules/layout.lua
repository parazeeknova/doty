hl.config({
    general = {
        layout = "scrolling"
    },
    scrolling = {
        column_width = 0.6,
        follow_focus = true,
        direction = "right",
        fullscreen_on_one_column = true,
        wrap_focus = false,
        wrap_swapcol = false
    },
    dwindle = {
        preserve_split = true
    }
})

local colors = {}
local colors_status, c = pcall(require, 'modules.colors')
if colors_status then
    colors = c
else
    colors = {
        shadow_color = "0xee1a1a1a"
    }
end

-- This requires https://github.com/yayuuu/hyprland-scroll-overview plugin
-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git && hyprpm update
if hl.plugin and hl.plugin.scrolloverview then
    hl.plugin.scrolloverview.configure({
        gesture_distance = 300,
        scale = 0.6,
        workspace_gap = 10,
        wallpaper = 0,
        blur = true,
        shadow = {
            enabled = false,
            range = 6,
            render_power = 2,
            color = tonumber(colors.shadow_color) or 0xee1a1a1a
        }
    })
end
