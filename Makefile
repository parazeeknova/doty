.PHONY: sync rebuild

sync:
	$(MAKE) -C wabi install
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' modules/features/wm/theming/.config/qt5ct/qt5ct.conf
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' modules/features/wm/theming/.config/qt6ct/qt6ct.conf

rebuild:
	sudo nixos-rebuild switch --flake .#apostrophe
