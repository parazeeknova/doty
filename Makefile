.PHONY: sync rebuild update-zcode

sync:
	$(MAKE) -C wabi install

rebuild:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_zcode
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild

update-zcode:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_zcode
	./wabi/target/release/update_zcode
