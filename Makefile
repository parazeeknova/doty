.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install

rebuild:
	sudo nixos-rebuild switch --flake .#apostrophe
