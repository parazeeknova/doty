.PHONY: sync rebuild setup-zen-autoconfig

sync:
	$(MAKE) -C wabi install
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt5ct/qt5ct.conf
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt6ct/qt6ct.conf

rebuild:
	sudo nixos-rebuild switch --flake .#apostrophe

# One-time system install for fx-autoconfig enables chrome/JS/*.uc.js loading. requires sudo, Run once after cloning the repo, then restart Zen.
setup-zen-autoconfig:
	sudo scripts/setup-zen-autoconfig.sh
