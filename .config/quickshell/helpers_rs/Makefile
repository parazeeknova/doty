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
	mkdir -p ../battery_popup ../volume_popup ../osd/bin ../network_popup ../bluetooth_popup ../brightness_popup ../notif_popup ../sysmon_popup ../podman_popup ../media_popup ../vm_popup ../../rofi/scripts
	cp target/release/get_battery_status ../battery_popup/get_battery_status
	cp target/release/log_battery ../battery_popup/log_battery
	cp target/release/get_audio_status ../volume_popup/get_audio_status
	cp target/release/osdctl ../osd/bin/osdctl
	cp target/release/get_network_status ../network_popup/get_network_status
	cp target/release/get_bluetooth_status ../bluetooth_popup/get_bluetooth_status
	cp target/release/get_brightness_status ../brightness_popup/get_brightness_status
	cp target/release/get_notif_status ../notif_popup/get_notif_status
	cp target/release/get_sysmon_status ../sysmon_popup/get_sysmon_status
	cp target/release/get_podman_status ../podman_popup/get_podman_status
	cp target/release/get_media_status ../media_popup/get_media_status
	cp target/release/get_vm_status ../vm_popup/get_vm_status
	cp target/release/ports_menu ../../rofi/scripts/ports_menu

