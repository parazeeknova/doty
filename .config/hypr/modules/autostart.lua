-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd("sh -lc 'if command -v quickshell >/dev/null 2>&1; then quickshell --config osd; elif command -v qs >/dev/null 2>&1; then qs --config osd; fi'")
	hl.exec_cmd("waybar")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("systemctl --user start ssh-agent.service && ssh-add ~/.ssh/id_ed25519")
end)
