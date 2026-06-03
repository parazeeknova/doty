--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Example window rules that are useful
hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name = "suppress-maximize-events",
    match = {
        class = ".*"
    },

    suppress_event = "maximize"
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false
    },

    no_focus = true
})

hl.layer_rule({
    name = "rofi-dropdown",
    match = {
        namespace = "rofi"
    },
    animation = "slide top",
    blur = true
})

hl.window_rule({
    name = "satty-float",
    match = {
        class = "satty"
    },
    float = true,
    size = {800, 400},
    center = true
})

hl.window_rule({
    name = "thunar-floating",
    match = {
        initial_class = "thunar.floating",
        initial_title = ".* - Thunar$"
    },
    float = true,
    size = {1000, 600},
    center = true
})

hl.window_rule({
    name = "ghostty-floating",
    match = {
        class = "ghostty.floating",
        title = ".+"
    },
    float = true,
    size = {1000, 600},
    center = true
})

hl.layer_rule({
    name = "quickshell-blur",
    match = {
        namespace = "quickshell"
    },
    animation = "slide left",
    dim_around = true,
    blur = true,
    ignore_alpha = 0.01
})

hl.layer_rule({
    name = "waybar-blur",
    match = {
        namespace = "waybar"
    },
    animation = "slide left",
    blur = true,
    ignore_alpha = 0.01
})

hl.layer_rule({
    name = "osd-blur",
    match = {
        namespace = "osd"
    },
    animation = "slide top",
    blur = true,
    ignore_alpha = 0.01
})

hl.layer_rule({
    name = "mako-blur",
    match = {
        namespace = "notifications"
    },
    blur = true,
    animation = "slide top",
    ignore_alpha = 0.01
})

hl.layer_rule({
    name = "wallpaper-switcher-effects",
    match = {
        namespace = "wallpaper_switcher"
    },
    animation = "slide left",
    dim_around = true
})

-- Workspace assignments for specific applications using exact class names (anchored regex)
local workspace_assignments = {
    ["1"] = {"^zen$", "^brave-origin-nightly$"},
    ["2"] = {"^Code$", "^code-insiders$", "^dev\\.warp\\.Warp$"},
    ["3"] = {"^thunar$"},
    ["4"] = {"^com\\.mitchellh\\.ghostty$"},
    ["5"] = {"^vesktop$", "^TelegramDesktop$"},
    ["9"] = {"^virt-manager$", "^qemu.*$", "^Qemu.*$"},
    ["10"] = {"^[Vv]mware.*$"}
}

for ws, classes in pairs(workspace_assignments) do
    for _, class in ipairs(classes) do
        hl.window_rule({
            match = {
                class = class
            },
            workspace = ws
        })
    end
end

-- Scratchpad rules for GitKraken & Helium Browser
hl.window_rule({
    name = "gitkraken-scratchpad",
    match = {
        class = "^gitkraken$"
    },
    workspace = "special:gitkraken",
    float = true,
    size = {1200, 800},
    center = true
})

hl.window_rule({
    name = "helium-scratchpad",
    match = {
        class = "^helium$"
    },
    workspace = "special:helium",
    float = true,
    size = {1200, 800},
    center = true
})

-- Force full opacity for VMware Workstation
hl.window_rule({
    name = "vmware-opacity",
    match = {
        class = "^[Vv]mware.*$"
    },
    opacity = "1.0 override 1.0 override"
})

-- Force full opacity for QEMU/KVM/Virt-manager VMs
hl.window_rule({
    name = "qemu-kvm-opacity",
    match = {
        class = "^(virt-manager|[Qq]emu.*)$"
    },
    opacity = "1.0 override 1.0 override"
})

