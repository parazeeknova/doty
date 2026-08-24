.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_verso --bin update_tldraw --bin update_hypr_plugins --bin update_portless --bin update_herdr --bin update_terminal_browser --bin update_terminal_code --bin update_suwayomi --bin update_bun
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild
