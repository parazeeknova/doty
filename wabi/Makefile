.PHONY: all update lint format build install

all: build install

update:
	cargo update

lint:
	cargo clippy --all-targets -- -D warnings

format:
	cargo fmt --all

build:
	cargo build --release

install: build
	@echo "==> Stopping running daemons before install..."
	-pkill -f battery_daemon 2>/dev/null || true
	-pkill -f wallpaper_thumb_watcher 2>/dev/null || true
	-pkill -f screentime_daemon 2>/dev/null || true
	-pkill -f mtp_notify 2>/dev/null || true
	-pkill -f get_voxtype_status 2>/dev/null || true
	-pkill -f mail_notifier 2>/dev/null || true
	@sleep 0.5
	mkdir -p ../modules/features/wm/quickshell/battery_popup ../modules/features/wm/quickshell/volume_popup ../modules/features/wm/quickshell/osd/bin ../modules/features/wm/quickshell/network_popup ../modules/features/wm/quickshell/clipboard_popup ../modules/features/wm/quickshell/bluetooth_popup ../modules/features/wm/quickshell/brightness_popup ../modules/features/wm/quickshell/notif_popup ../modules/features/wm/quickshell/sysmon_popup ../modules/features/wm/quickshell/podman_popup ../modules/features/wm/quickshell/media_popup ../modules/features/wm/quickshell/vm_popup ../modules/features/wm/quickshell/ports_popup ../modules/features/wm/quickshell/sunset_popup ../modules/features/wm/quickshell/apps_popup ../modules/features/wm/quickshell/recents_popup ../modules/features/wm/quickshell/wallpaper_switcher ../modules/features/wm/quickshell/github_graph ../modules/features/wm/shortcut_popup ../modules/features/wm/volume_popup ../modules/features/wm/waybar/scripts ../modules/features/wm/theming/scripts ../modules/scripts
	cp --remove-destination target/release/get_battery_status ../modules/features/wm/quickshell/battery_popup/get_battery_status
	cp --remove-destination target/release/log_battery ../modules/features/wm/quickshell/battery_popup/log_battery
	cp --remove-destination target/release/battery_daemon ../modules/features/wm/quickshell/battery_popup/battery_daemon
	cp --remove-destination target/release/get_audio_status ../modules/features/wm/quickshell/volume_popup/get_audio_status
	cp --remove-destination target/release/osdctl ../modules/features/wm/quickshell/osd/bin/osdctl
	cp --remove-destination target/release/get_network_status ../modules/features/wm/quickshell/network_popup/get_network_status
	cp --remove-destination target/release/get_bluetooth_status ../modules/features/wm/quickshell/bluetooth_popup/get_bluetooth_status
	cp --remove-destination target/release/get_brightness_status ../modules/features/wm/quickshell/brightness_popup/get_brightness_status
	cp --remove-destination target/release/get_notif_status ../modules/features/wm/quickshell/notif_popup/get_notif_status
	cp --remove-destination target/release/get_sysmon_status ../modules/features/wm/quickshell/sysmon_popup/get_sysmon_status
	cp --remove-destination target/release/get_podman_status ../modules/features/wm/quickshell/podman_popup/get_podman_status
	cp --remove-destination target/release/get_media_status ../modules/features/wm/quickshell/media_popup/get_media_status
	cp --remove-destination target/release/get_vm_status ../modules/features/wm/quickshell/vm_popup/get_vm_status
	cp --remove-destination target/release/get_ports_status ../modules/features/wm/quickshell/ports_popup/get_ports_status
	cp --remove-destination target/release/get_sunset_status ../modules/features/wm/quickshell/sunset_popup/get_sunset_status
	cp --remove-destination target/release/get_apps_list ../modules/features/wm/quickshell/apps_popup/get_apps_list
	cp --remove-destination target/release/get_recents_list ../modules/features/wm/quickshell/recents_popup/get_recents_list
	cp --remove-destination target/release/get_github_repos ../modules/features/wm/quickshell/apps_popup/get_github_repos
	cp --remove-destination target/release/waybar_toggle ../modules/features/wm/waybar/scripts/waybar_toggle
	cp --remove-destination target/release/toggle_widgets ../modules/features/wm/waybar/scripts/toggle_widgets
	cp --remove-destination target/release/wabi_power ../modules/features/wm/waybar/scripts/wabi_power
	cp --remove-destination target/release/tray_count ../modules/features/wm/waybar/scripts/tray_count
	cp --remove-destination target/release/get_voxtype_status ../modules/features/wm/waybar/scripts/get_voxtype_status
	cp --remove-destination target/release/wallpaper_thumb_watcher ../modules/features/wm/quickshell/wallpaper_switcher/wallpaper_thumb_watcher
	cp --remove-destination target/release/get_github_graph ../modules/features/wm/quickshell/github_graph/get_github_graph
	cp --remove-destination target/release/theme_switcher ../modules/scripts/theme_switcher
	cp --remove-destination target/release/theme_switcher ../modules/features/wm/theming/scripts/theme_switcher
	cp --remove-destination target/release/kbd_aura ../modules/scripts/kbd_aura
	cp --remove-destination target/release/set_wallpaper ../modules/scripts/set_wallpaper_bin
	cp --remove-destination target/release/toggle_wallpaper_pause ../modules/scripts/toggle_wallpaper_pause
	cp --remove-destination target/release/parse_binds ../modules/features/wm/quickshell/shortcut_popup/parse_binds
	cp --remove-destination target/release/caffeine ../modules/features/wm/quickshell/brightness_popup/caffeine
	cp --remove-destination target/release/decode_cliphist ../modules/features/wm/quickshell/clipboard_popup/decode_cliphist
	cp --remove-destination target/release/ghostty_tmux ../modules/scripts/ghostty_tmux
	mkdir -p $(HOME)/.local/bin
	cp --remove-destination target/release/screentime_daemon $(HOME)/.local/bin/screentime_daemon
	cp --remove-destination target/release/get_screentime_status $(HOME)/.local/bin/get_screentime_status
	cp --remove-destination target/release/check_daemons $(HOME)/.local/bin/check_daemons
	cp --remove-destination target/release/mtp_notify $(HOME)/.local/bin/mtp_notify
	cp --remove-destination target/release/mail_notifier $(HOME)/.local/bin/mail_notifier
	cp --remove-destination target/release/update_zcode $(HOME)/.local/bin/update_zcode
	cp --remove-destination target/release/update_verso $(HOME)/.local/bin/update_verso
	cp --remove-destination target/release/update_opencode_desktop $(HOME)/.local/bin/update_opencode_desktop
	cp --remove-destination target/release/update_qoder $(HOME)/.local/bin/update_qoder
	cp --remove-destination target/release/update_harper $(HOME)/.local/bin/update_harper



	@echo "==> Restarting daemons..."
	@uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon >/dev/null 2>&1 &
	@uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher >/dev/null 2>&1 &
	@uwsm app -- ~/.local/bin/screentime_daemon >/dev/null 2>&1 &
	@uwsm app -- ~/.local/bin/mtp_notify >/dev/null 2>&1 &
	@uwsm app -- ~/.local/bin/mail_notifier >/dev/null 2>&1 &
	@echo "==> Install complete."
