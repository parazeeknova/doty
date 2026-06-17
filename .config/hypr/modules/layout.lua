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

-- This requires https://github.com/VirtCode/hypr-dynamic-cursors plugin
-- hyprpm add https://github.com/virtcode/hypr-dynamic-cursors && hyprpm enable dynamic-cursors
hl.config {
    plugin = {
        dynamic_cursors = {
            -- enables the plugin
            enabled = true,
            -- sets the cursor behaviour, supports these values:
            -- tilt    - tilt the cursor based on x-velocity
            -- rotate  - rotate the cursor based on movement direction
            -- stretch - stretch the cursor shape based on direction and velocity
            -- none    - do not change the cursor's behaviour
            mode = "tilt",
            -- minimum angle difference in degrees after which the shape is changed
            -- smaller values are smoother, but more expensive for hw cursors
            threshold = 1,

            rotate = {
                -- length in px of the simulated stick used to rotate the cursor
                -- most realistic if this is your actual cursor size
                length = 20,
                -- clockwise offset applied to the angle in degrees
                -- this will apply to ALL shapes
                offset = 0.0
            },

            tilt = {
                -- controls how powerful the tilt is, the lower, the more power
                -- this value controls at which speed (px/s) the full tilt is reached
                limit = 2000,
                -- relationship between speed and tilt, supports these values:
                -- linear             - a linear function is used
                -- quadratic          - a quadratic function is used (most realistic to actual air drag)
                -- negative_quadratic - negative version of the quadratic one, feels more aggressive
                -- see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
                activation = "negative_quadratic",
                -- time window (ms) over which the speed is calculated
                -- higher values will make slow motions smoother but more delayed
                window = 100,
                -- full tilt for each side (°)
                full = 40
            },

            stretch = {
                -- controls how much the cursor is stretched
                -- this value controls at which speed (px/s) the full stretch is reached
                -- the full stretch being twice the original length
                limit = 3000,
                -- relationship between speed and stretch amount, supports these values:
                -- linear             - a linear function is used
                -- quadratic          - a quadratic function is used
                -- negative_quadratic - negative version of the quadratic one, feels more aggressive
                -- see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
                activation = "quadratic",
                -- time window (ms) over which the speed is calculated
                -- higher values will make slow motions smoother but more delayed
                window = 100
            },

            -- configure shake to find
            -- magnifies the cursor if its is being shaken
            shake = {
                -- enables shake to find
                enabled = false,
                -- controls how soon a shake is detected
                -- lower values mean sooner
                threshold = 6.0,
                -- magnification level immediately after shake start
                base = 4.0,
                -- magnification increase per second when continuing to shake
                speed = 4.0,
                -- how much the speed is influenced by the current shake intensity
                influence = 0.0,
                -- maximal magnification the cursor can reach
                -- values below 1 disable the limit (e.g. 0)
                limit = 0.0,
                -- time in milliseconds the cursor will stay magnified after a shake has ended
                timeout = 2000,
                -- show cursor behaviour `tilt`, `rotate`, etc. while shaking
                effects = false,
                -- enable ipc events for shake
                -- see the `ipc` section below
                ipc = false
            },
            -- use hyprcursor to get a higher resolution texture when the cursor is magnified
            -- see the `hyprcursor` section below
            hyprcursor = {

                -- use nearest-neighbour (pixelated) scaling when magnifying beyond texture size
                -- this will also have effect without hyprcursor support being enabled
                -- 0 - never use pixelated scaling
                -- 1 - use pixelated when no highres image
                -- 2 - always use pixelated scaling
                nearest = 1,
                -- enable dedicated hyprcursor support
                enabled = true,
                -- resolution in pixels to load the magnified shapes at
                -- be warned that loading a very high-resolution image will take a long time and might impact memory consumption
                -- -1 means we use [normal cursor size] * [shake:base option]
                resolution = -1,
                -- shape to use when clientside cursors are being magnified
                -- see the shape-name property of shape rules for possible names
                -- specifying clientside will use the actual shape, but will be pixelated
                fallback = "clientside"
            }
        }
    }
}
