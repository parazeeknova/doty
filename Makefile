.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild
