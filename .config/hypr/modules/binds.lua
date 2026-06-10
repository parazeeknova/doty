---------------------
---- Keybindings ----
---------------------
local mainMod = "SUPER"
local terminal = "uwsm app -- ghostty"
local fileManager = "uwsm app -- thunar"
local dotfiles = os.getenv("WABI_DOTFILES_DIR") or (os.getenv("HOME") .. "/doty")
local osdctl = dotfiles .. "/.config/quickshell/osd/bin/osdctl"

---------------------
---  Applications ---
---------------------

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("uwsm app -- ghostty --class=ghostty.floating"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("uwsm app -- kitty"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("uwsm app -- warp-terminal"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp
    .exec_cmd("env WAYLAND_DISPLAY=\"\" DBUS_SESSION_BUS_ADDRESS=\"\" uwsm app -- thunar --class=thunar.floating"))

-- Browsers
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(
    'hyprctl clients | grep -q "class: zen" && hyprctl dispatch \'hl.dsp.focus({ window = "class:zen" })\' || uwsm app -- zen-browser'))

-- Editors
hl.bind(mainMod .. " + semicolon", hl.dsp.exec_cmd(
    'hyprctl clients | grep -q "class: code-insiders" && hyprctl dispatch \'hl.dsp.focus({ window = "class:code-insiders" })\' || uwsm app -- code-insiders'))

---------------------
---    Windows    ---
---------------------

local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + C", hl.dsp.window.float({
    action = "toggle"
}))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), {
    mouse = true
})
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), {
    mouse = true
})

---------------------
---    Layout     ---
---------------------

hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- Focus with arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({
    direction = "left"
}))
hl.bind(mainMod .. " + right", hl.dsp.focus({
    direction = "right"
}))
hl.bind(mainMod .. " + up", hl.dsp.focus({
    direction = "up"
}))
hl.bind(mainMod .. " + down", hl.dsp.focus({
    direction = "down"
}))

---------------------
---  Workspaces   ---
---------------------

-- Switch/move workspaces [1-0]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({
        workspace = i
    }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({
        workspace = i
    }))
end

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({
    workspace = "e+1"
}))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({
    workspace = "e-1"
}))

-- Special workspaces (scratchpads)
hl.bind(mainMod .. " + A", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({
    workspace = "special:magic"
}))

hl.bind(mainMod .. " + Z", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({
    workspace = "special:terminal"
}))

-- Scratchpads (Toggle or Launch)
hl.bind(mainMod .. " + G", hl.dsp
    .exec_cmd('pgrep -x gitkraken && hyprctl dispatch \'hl.dsp.workspace.toggle_special("gitkraken")\' || gitkraken'))
hl.bind(mainMod .. " + ALT + H", hl.dsp
    .exec_cmd('pgrep -x helium && hyprctl dispatch \'hl.dsp.workspace.toggle_special("helium")\' || helium-browser'))

---------------------
---     Rofi      ---
---------------------

hl.bind(mainMod .. " + SPACE", hl.dsp
    .exec_cmd("~/.config/rofi/scripts/rofi_wrap -show drun -mesg 'applications' -placeholder 'search applications'"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show recents"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show power"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show sunset"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show ports -mesg 'occupied ports'"))
hl.bind("XF86Launch3", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show profile"))

---------------------
---   Pyprland    ---
---------------------
hl.bind("ALT + TAB", hl.dsp.exec_cmd("pypr expose"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("pypr layout_center toggle"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("pypr toggle term"))

-- Quickshell popups
hl.bind(mainMod .. " + V", hl.dsp
    .exec_cmd("quickshell -c clipboard_popup ipc call clipboard_popup close || quickshell --config clipboard_popup"))
hl.bind(mainMod .. " + comma",
    hl.dsp.exec_cmd("quickshell -c emoji_popup ipc call emoji_popup close || quickshell --config emoji_popup"))
hl.bind(mainMod .. " + SHIFT + M",
    hl.dsp.exec_cmd("quickshell -c volume_popup ipc call volume_popup close || quickshell --config volume_popup"))
hl.bind(mainMod .. " + SHIFT + V",
    hl.dsp.exec_cmd("quickshell -c vm_popup ipc call vm_popup close || quickshell --config vm_popup"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp
    .exec_cmd("quickshell -c network_popup ipc call network_popup close || quickshell --config network_popup"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp
    .exec_cmd("quickshell -c bluetooth_popup ipc call bluetooth_popup close || quickshell --config bluetooth_popup"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(
    "quickshell -c brightness_popup ipc call brightness_popup close || quickshell --config brightness_popup"))
hl.bind(mainMod .. " + SHIFT + N",
    hl.dsp.exec_cmd("quickshell -c notif_popup ipc call notif_popup close || quickshell --config notif_popup"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("~/.config/rofi/scripts/toggle_glass"))
hl.bind(mainMod .. " + O", hl.dsp.window.set_prop({
    prop = "opaque",
    value = "toggle",
    window = "active"
}))
hl.bind(mainMod .. " + ALT + slash",
    hl.dsp.exec_cmd("quickshell -c podman_popup ipc call podman_popup close || quickshell --config podman_popup"))
hl.bind(mainMod .. " + SHIFT + G",
    hl.dsp.exec_cmd("quickshell -c media_popup ipc call media_popup close || quickshell --config media_popup"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(
    "quickshell -c wallpaper_switcher ipc call wallpaper_switcher close || quickshell --config wallpaper_switcher"))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd(
    "quickshell -c colorscheme_popup ipc call colorscheme_popup close || quickshell --config colorscheme_popup"))
hl.bind(mainMod .. " + K", hl.dsp
    .exec_cmd("quickshell -c shortcut_popup ipc call shortcut_popup close || quickshell --config shortcut_popup"))
hl.bind("SUPER_L", hl.dsp
    .exec_cmd("quickshell -c workspace_popup ipc call workspace_popup close || quickshell --config workspace_popup"), {
    release = true,
    ignore_mods = true
})

---------------------
---   Screenshots ---
---------------------

local media_helper = "$HOME/.config/quickshell/media_popup/get_media_status"
local ss_dir = "$HOME/Pictures/Screenshots"
local ss_path = ss_dir .. "/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png"
local grimhyprctl = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
local slurp_cmd = "slurp -b \\#1d2021b0 -c \\#d5c4a1ff -s \\#00000000"

local save_register_ss = "mkdir -p " .. ss_dir .. " && FILE=" .. ss_path .. " && " .. grimhyprctl ..
                             " \"$FILE\" && wl-copy < \"$FILE\" && " .. media_helper ..
                             " add-asset screenshot \"$FILE\""
local save_register_ss_region = "mkdir -p " .. ss_dir .. " && FILE=" .. ss_path .. " && grim -g \"$(" .. slurp_cmd ..
                                    ")\" \"$FILE\" && wl-copy < \"$FILE\" && " .. media_helper ..
                                    " add-asset screenshot \"$FILE\""
local save_register_ss_region_swappy = "mkdir -p " .. ss_dir .. " && FILE=" .. ss_path .. " && grim -g \"$(" ..
                                           slurp_cmd .. ")\" \"$FILE\" && swappy -f \"$FILE\" -o \"$FILE\" && " ..
                                           media_helper .. " add-asset screenshot \"$FILE\""

hl.bind("Print", hl.dsp.exec_cmd("sh -c '" .. save_register_ss .. "'"), {
    locked = true
})
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("sh -c '" .. save_register_ss_region_swappy .. "'"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("sh -c '" .. save_register_ss_region .. "'"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(
    "sh -c 'if ! command -v tesseract &> /dev/null; then notify-send -t 4000 -a \"OCR\" \"Tesseract not installed\" \"Please run: sudo pacman -S tesseract tesseract-data-eng\"; exit 1; fi; grim -g \"$(" ..
        slurp_cmd ..
        ")\" /tmp/ocr_image.png && TEXT=$(tesseract /tmp/ocr_image.png stdout 2>/dev/null) && rm /tmp/ocr_image.png && if [ ! -z \"$TEXT\" ]; then echo -n \"$TEXT\" | wl-copy && " ..
        media_helper ..
        " add ocr \"$TEXT\" && notify-send -t 1500 -h string:x-canonical-private-synchronous:ocr-notify -a \"OCR\" \"Extracted text copied to clipboard\"; else notify-send -t 1500 -a \"OCR\" \"No text found\"; fi'"))

---------------------
---    System     ---
---------------------

-- Waybar toggle
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/waybar/scripts/waybar_toggle"))

-- Lock screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock -c ~/.config/hypr/hyprlock.conf"))

-- Color picker (also registers the color in the media popup history)
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("$HOME/.config/quickshell/media_popup/get_media_status pick-color"))

-- Power menu / Logout
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("~/.config/rofi/scripts/rofi_wrap -show power"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(
    "sh -c 'if command -v uwsm >/dev/null 2>&1 && uwsm check; then uwsm stop; else hyprctl dispatch exit; fi'"))

-- Caps lock OSD
hl.bind("Caps_Lock", hl.dsp.exec_cmd(osdctl .. " caps toggle"), {
    locked = true
})

-- Laptop multimedia keys (volume & brightness)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osdctl .. " volume up"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osdctl .. " volume down"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osdctl .. " volume mute"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(osdctl .. " volume mic-mute"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osdctl .. " brightness up"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osdctl .. " brightness down"), {
    locked = true,
    repeating = true
})
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(osdctl .. " kbdbrightness up"), {
    locked = true,
    repeating = true
})
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(osdctl .. " kbdbrightness down"), {
    locked = true,
    repeating = true
})

-- Media player
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), {
    locked = true
})
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true
})
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true
})
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), {
    locked = true
})
