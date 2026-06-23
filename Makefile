.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	rustc rebuild.rs -o rebuild && ./rebuild
