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
	cp target/release/get_battery_status ../battery_popup/get_battery_status
	cp target/release/log_battery ../battery_popup/log_battery
	cp target/release/get_audio_status ../volume_popup/get_audio_status
