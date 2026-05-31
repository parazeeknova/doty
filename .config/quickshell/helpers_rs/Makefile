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
	mkdir -p ../battery_popup ../volume_popup ../osd/bin ../network_popup ../bluetooth_popup ../brightness_popup ../notif_popup
	cp target/release/get_battery_status ../battery_popup/get_battery_status
	cp target/release/log_battery ../battery_popup/log_battery
	cp target/release/get_audio_status ../volume_popup/get_audio_status
	cp target/release/osdctl ../osd/bin/osdctl
	cp target/release/get_network_status ../network_popup/get_network_status
	cp target/release/get_bluetooth_status ../bluetooth_popup/get_bluetooth_status
	cp target/release/get_brightness_status ../brightness_popup/get_brightness_status
	cp target/release/get_notif_status ../notif_popup/get_notif_status
