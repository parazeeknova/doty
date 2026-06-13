-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- Scrolling
-- hl.workspace_rule({ workspace = "9", layout_opts = { direction = "down" } })
-- hl.workspace_rule({ workspace = "10", layout_opts = { direction = "down" } })

-- Disable blur for xwayland context menus
hl.window_rule({
    match = {
        class = "^()$",
        title = "^()$",
        xwayland = true
    },
    no_blur = true,
    opacity = 1
})

-- Floating for dialogs
hl.window_rule({
    match = {
        title = "^(Open File)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(Open File)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(Select a File)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(Select a File)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(Open Folder)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(Open Folder)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(Save As)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(Save As)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(Library)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(Library)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(File Upload)(.*)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(File Upload)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(.*)(wants to save)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(.*)(wants to save)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^(.*)(wants to open)$"
    },
    center = true
})
hl.window_rule({
    match = {
        title = "^(.*)(wants to open)$"
    },
    float = true
})

-- Dialogs & Authentication Floating
hl.window_rule({
    match = {
        class = "^(xdg-desktop-portal-.*)$"
    },
    float = true,
    center = true
})
hl.window_rule({
    match = {
        class = "^(polkit-.*-authentication-agent-.*)$"
    },
    float = true,
    center = true
})
hl.window_rule({
    match = {
        title = "^(Confirm to replace files)$"
    },
    float = true
})

-- Picture-in-Picture
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    keep_aspect_ratio = true
})
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    move = { "(monitor_w*0.73)", "(monitor_h*0.72)" }
})
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    size = { "(monitor_w*0.25)", "(monitor_h*0.25)" }
})
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    float = true
})
hl.window_rule({
    match = {
        title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
    },
    pin = true
})

-- Screen sharing
hl.window_rule({
    match = {
        title = ".*is sharing (a window|your screen).*"
    },
    float = true
})
hl.window_rule({
    match = {
        title = ".*is sharing (a window|your screen).*"
    },
    pin = true
})
hl.window_rule({
    match = {
        title = ".*is sharing (a window|your screen).*"
    },
    move = { "(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)" }
})
