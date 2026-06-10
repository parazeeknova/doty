.PHONY: sync setup-zen-autoconfig

sync:
	$(MAKE) -C .config/hypr/wabi install
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt5ct/qt5ct.conf
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt6ct/qt6ct.conf
	stow . --ignore='.antigravitycli'

# One-time system install for fx-autoconfig (enables chrome/JS/*.uc.js loading).
# Requires sudo. Run once after cloning the repo, then restart Zen.
setup-zen-autoconfig:
	sudo scripts/setup-zen-autoconfig.sh