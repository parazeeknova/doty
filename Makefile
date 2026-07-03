.PHONY: sync rebuild update-zcode

sync:
	$(MAKE) -C wabi install

rebuild:
	rustc wabi/rebuild.rs -o wabi/rebuild && ./wabi/rebuild

update-zcode:
	./wabi/update-zcode.py
