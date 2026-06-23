.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	./rebuild.sh
