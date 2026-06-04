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
	mkdir -p ../../quickshell/battery_popup ../../quickshell/volume_popup ../../quickshell/osd/bin ../../quickshell/network_popup ../../quickshell/bluetooth_popup ../../quickshell/brightness_popup ../../quickshell/notif_popup ../../quickshell/sysmon_popup ../../quickshell/podman_popup ../../quickshell/media_popup ../../quickshell/vm_popup ../rofi/scripts ../../quickshell/wallpaper_switcher ../../quickshell/github_graph ../../../scripts
	cp target/release/get_battery_status ../../quickshell/battery_popup/get_battery_status
	cp target/release/log_battery ../../quickshell/battery_popup/log_battery
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
	cp target/release/ports_menu ../rofi/scripts/ports_menu
	cp target/release/wallpaper_thumb_watcher ../../quickshell/wallpaper_switcher/wallpaper_thumb_watcher
	cp target/release/get_github_graph ../../quickshell/github_graph/get_github_graph
	cp target/release/theme_switcher ../../../scripts/theme_switcher



