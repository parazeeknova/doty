.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	cargo build --manifest-path wabi/Cargo.toml --release --bin update_verso --bin update_tldraw --bin update_hypr_plugins
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild


