---------------------
---- Keybindings ----
---------------------

local mainMod = "SUPER"
local terminal = "ghostty"
local fileManager = "thunar"
local osdctl = "~/doty/.config/quickshell/osd/bin/osdctl"
local hyprspace = require("hyprspace")

---------------------
---  Applications ---
---------------------

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("warp-terminal"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Browsers
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))

-- Editors
hl.bind(mainMod .. " + semicolon", hl.dsp.exec_cmd("code-insiders"))

---------------------
---    Windows    ---
---------------------

local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---------------------
---    Layout     ---
---------------------

hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- Focus with arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

---------------------
---  Workspaces   ---
---------------------

-- Switch/move workspaces [1-0]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Special workspaces (scratchpads)
hl.bind(mainMod .. " + A", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + Z", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:terminal" }))

-- Overview (Hyprspace)
hl.bind("ALT + TAB", function()
	hyprspace.toggle()
end)

---------------------
---     Rofi      ---
---------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun -mesg 'applications'"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("rofi -show recents"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell --config notif_popup"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("rofi -show power"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("rofi -show sunset"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("rofi -show clip"))
hl.bind("XF86Launch3", hl.dsp.exec_cmd("rofi -show profile"))

-- Quickshell popups
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("quickshell --config volume_popup"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("quickshell --config network_popup"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("quickshell --config bluetooth_popup"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("quickshell --config brightness_popup"))

---------------------
---   Screenshots ---
---------------------

hl.bind("Print", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | swappy -f -'"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("sh -c 'grim - | swappy -f -'"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | satty -f -'"))

---------------------
---    System     ---
---------------------

-- Waybar toggle
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/doty/.config/waybar/scripts/launch.sh"))

-- Lock screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock -c ~/.config/hypr/hyprlock.conf"))

-- Color picker
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a -n"))

-- Power menu / Logout
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("rofi -show power"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))

-- Caps lock OSD
hl.bind("Caps_Lock", hl.dsp.exec_cmd(osdctl .. " caps toggle"), { locked = true })

-- Laptop multimedia keys (volume & brightness)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osdctl .. " volume up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osdctl .. " volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osdctl .. " volume mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(osdctl .. " volume mic-mute"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osdctl .. " brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osdctl .. " brightness down"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(osdctl .. " kbdbrightness up"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(osdctl .. " kbdbrightness down"), { locked = true, repeating = true })

-- Media player
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
