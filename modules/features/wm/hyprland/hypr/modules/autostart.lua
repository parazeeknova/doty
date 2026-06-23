-------------------
---- AUTOSTART ----
-------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
local dotfiles = os.getenv("WABI_DOTFILES_DIR") or (os.getenv("HOME") .. "/doty")

hl.on("hyprland.start", function()
    -- System Startups
    hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.config/hypr/plugins/hyprglass.so")
    hl.exec_cmd("hyprpm reload -n; " .. dotfiles .. "/scripts/theme_switcher restore")
    hl.exec_cmd("hyprctl setcursor capitaine-cursors 24")
    hl.exec_cmd("uwsm app -- udiskie --tray --notify")
    -- Restore glass state from persistent cache to tmpfs
    hl.exec_cmd(
        "sh -c 'cat ~/.cache/quickshell/glass_state 2>/dev/null > /tmp/quickshell_glass_state || printf true > /tmp/quickshell_glass_state'")
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config osd; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config osd; fi'")
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config github_graph; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config github_graph; fi'")
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config workspace_overview; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config workspace_overview; fi'")
    -- Restore waybar state from persistent cache to tmpfs and start Waybar if enabled
    hl.exec_cmd(
        "sh -c 'VAL=$(cat ~/.cache/quickshell/waybar_state 2>/dev/null || echo true); echo \"$VAL\" > /tmp/quickshell_waybar_state; if [ \"$VAL\" = \"true\" ]; then uwsm app -- waybar; fi'")
    hl.exec_cmd(
        "sh -c 'cat ~/.cache/quickshell/widgets_state 2>/dev/null > /tmp/quickshell_widgets_state || printf true > /tmp/quickshell_widgets_state'")
    hl.exec_cmd(
        "sh -c 'cat ~/.cache/quickshell/widgets_config 2>/dev/null > /tmp/quickshell_widgets_config || printf default > /tmp/quickshell_widgets_config'")
    hl.exec_cmd("sh -c 'sleep 2 && " .. dotfiles .. "/.config/waybar/scripts/toggle_widgets restore'")
    hl.exec_cmd("sh -c '" .. dotfiles ..
                    "/scripts/set_wallpaper \"$(cat ~/.cache/last_wallpaper 2>/dev/null || echo \"$HOME/Pictures/Anime/grey_lain_wallpaper.jpg\")\"'")
    hl.exec_cmd("uwsm app -- hyprsunset")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- pypr")
    hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
    hl.exec_cmd("uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher")
    hl.exec_cmd("uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon")
    hl.exec_cmd("uwsm app -- ~/.local/bin/screentime_daemon")
    hl.exec_cmd("uwsm app -- ~/.local/bin/mtp_notify")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(
        "systemctl --user start ssh-agent.service && sh -c 'sleep 3 && env SSH_ASKPASS=ssh-askpass ssh-add ~/.ssh/id_ed25519 < /dev/null'")
end)
