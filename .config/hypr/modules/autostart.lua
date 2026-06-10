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
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config osd; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config osd; fi'")
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config github_graph; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config github_graph; fi'")
    hl.exec_cmd(
        "sh -lc 'if command -v quickshell >/dev/null 2>&1; then uwsm app -- quickshell --config workspace_overview; elif command -v qs >/dev/null 2>&1; then uwsm app -- qs --config workspace_overview; fi'")
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd(
        "sh -c '" .. dotfiles .. "/scripts/set_wallpaper \"$(cat ~/.cache/last_wallpaper 2>/dev/null || echo \"$HOME/Pictures/Anime/grey_lain_wallpaper.jpg\")\"'")
    hl.exec_cmd("uwsm app -- hyprsunset")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- pypr")
    hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
    hl.exec_cmd("uwsm app -- " .. dotfiles .. "/scripts/theme_switcher restore")
    hl.exec_cmd("uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher")
    hl.exec_cmd("uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon")
    hl.exec_cmd("uwsm app -- ~/.local/bin/screentime_daemon")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(
        "systemctl --user start ssh-agent.service && sh -c 'sleep 3 && env SSH_ASKPASS=/usr/lib/seahorse/ssh-askpass ssh-add ~/.ssh/id_ed25519 < /dev/null'")
end)
