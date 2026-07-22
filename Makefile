.PHONY: sync rebuild update-zcode update-opencode-desktop update-qoder update-harper

sync:
	$(MAKE) -C wabi install

rebuild:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_zcode --bin update_verso --bin update_tldraw --bin update_opencode_desktop --bin update_qoder --bin update_harper
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild

update-zcode:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_zcode
	./wabi/target/release/update_zcode

update-opencode-desktop:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_opencode_desktop
	./wabi/target/release/update_opencode_desktop

update-qoder:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_qoder
	./wabi/target/release/update_qoder

update-harper:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_harper
	./wabi/target/release/update_harper



