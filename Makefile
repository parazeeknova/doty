.PHONY: sync

sync:
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt5ct/qt5ct.conf
	sed -i 's|color_scheme_path=/home/[^/]*/\.config|color_scheme_path=$(HOME)/.config|' .config/qt6ct/qt6ct.conf
	stow . --ignore='.antigravitycli'