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
	@sleep 0.5
	mkdir -p ../../quickshell/battery_popup ../../quickshell/volume_popup ../../quickshell/osd/bin ../../quickshell/network_popup ../../quickshell/bluetooth_popup ../../quickshell/brightness_popup ../../quickshell/notif_popup ../../quickshell/sysmon_popup ../../quickshell/podman_popup ../../quickshell/media_popup ../../quickshell/vm_popup ../../rofi/scripts ../../quickshell/wallpaper_switcher ../../quickshell/github_graph ../../../scripts ../../waybar/scripts
	cp target/release/get_battery_status ../../quickshell/battery_popup/get_battery_status
	cp target/release/log_battery ../../quickshell/battery_popup/log_battery
	cp target/release/battery_daemon ../../quickshell/battery_popup/battery_daemon
	cp target/release/get_audio_status ../../quickshell/volume_popup/get_audio_status
	cp target/release/osdctl ../../quickshell/osd/bin/osdctl
	cp target/release/get_network_status ../../quickshell/network_popup/get_network_status
	cp target/release/get_bluetooth_status ../../quickshell/bluetooth_popup/get_bluetooth_status
	cp target/release/get_brightness_status ../../quickshell/brightness_popup/get_brightness_status
	cp target/release/get_notif_status ../../quickshell/notif_popup/get_notif_status
	cp target/release/get_sysmon_status ../../quickshell/sysmon_popup/get_sysmon_status
	cp target/release/get_podman_status ../../quickshell/podman_popup/get_podman_status
	cp target/release/get_media_status ../../quickshell/media_popup/get_media_status
	cp target/release/get_vm_status ../../quickshell/vm_popup/get_vm_status
	cp target/release/ports_menu ../../rofi/scripts/ports_menu
	cp target/release/caffeine ../../rofi/scripts/caffeine
	cp target/release/cliphist ../../rofi/scripts/cliphist
	cp target/release/notif_center ../../rofi/scripts/notif_center
	cp target/release/power_menu ../../rofi/scripts/power_menu
	cp target/release/profile ../../rofi/scripts/profile
	cp target/release/recents ../../rofi/scripts/recents
	cp target/release/sunset ../../rofi/scripts/sunset
	cp target/release/toggle_glass ../../rofi/scripts/toggle_glass
	cp target/release/rofi_wrap ../../rofi/scripts/rofi_wrap
	cp target/release/waybar_toggle ../../waybar/scripts/waybar_toggle
	cp target/release/toggle_widgets ../../waybar/scripts/toggle_widgets
	cp target/release/tray_count ../../waybar/scripts/tray_count
	cp target/release/wallpaper_thumb_watcher ../../quickshell/wallpaper_switcher/wallpaper_thumb_watcher
	cp target/release/get_github_graph ../../quickshell/github_graph/get_github_graph
	cp target/release/theme_switcher ../../../scripts/theme_switcher
	cp target/release/set_wallpaper ../../../scripts/set_wallpaper_bin
	cp target/release/parse_binds ../../quickshell/shortcut_popup/parse_binds
	mkdir -p $(HOME)/.local/bin
	cp target/release/screentime_daemon $(HOME)/.local/bin/screentime_daemon
	cp target/release/get_screentime_status $(HOME)/.local/bin/get_screentime_status
	cp target/release/check_daemons $(HOME)/.local/bin/check_daemons
	@echo "==> Restarting daemons..."
	@uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon >/dev/null 2>&1 &
	@uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher >/dev/null 2>&1 &
	@uwsm app -- ~/.local/bin/screentime_daemon >/dev/null 2>&1 &
	@echo "==> Install complete."