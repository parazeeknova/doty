{ self, inputs, ... }:

let
  themeDir = ./.;
  repo = "/home/parazeeknova/doty";
  theming = "${repo}/modules/features/wm/theming";
in
{

  flake.nixosModules.parazeeknovaTheming = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {

      home.packages = [ pkgs.papirus-folders ];

      gtk = {
        enable = true;
        theme = {
          name = "wabi";
          package = pkgs.runCommand "wabi-gtk-theme" { } ''
            mkdir -p $out/share/themes/wabi
            cp -r ${themeDir}/.themes/wabi/* $out/share/themes/wabi/
          '';
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        cursorTheme = {
          name = "capitaine-cursors";
          package = pkgs.capitaine-cursors;
        };
        font = {
          name = "FiraCode Nerd Font";
          size = 9;
        };
        gtk4.theme = config.gtk.theme;
      };

      xdg.configFile = {
        # -- GTK Overrides (writable for theme_switcher) --
        "gtk-3.0/gtk.css".source = mkOutOfStoreSymlink "${theming}/.config/gtk-3.0/gtk.css";
        "gtk-3.0/colors.css".source = mkOutOfStoreSymlink "${theming}/.config/gtk-3.0/colors.css";
        "gtk-3.0/colors.css.template".source = mkOutOfStoreSymlink "${theming}/.config/gtk-3.0/colors.css.template";
        "gtk-3.0/settings.ini".source = mkOutOfStoreSymlink "${theming}/.config/gtk-3.0/settings.ini";
        "gtk-4.0/colors.css".source = mkOutOfStoreSymlink "${theming}/.config/gtk-4.0/colors.css";
        "gtk-4.0/colors.css.template".source = mkOutOfStoreSymlink "${theming}/.config/gtk-4.0/colors.css.template";
        "gtk-4.0/settings.ini".source = mkOutOfStoreSymlink "${theming}/.config/gtk-4.0/settings.ini";

        # -- Kvantum (writable for theme_switcher) --
        "Kvantum/kvantum.kvconfig".source = mkOutOfStoreSymlink "${theming}/.config/Kvantum/kvantum.kvconfig";
        "Kvantum/wabi".source = mkOutOfStoreSymlink "${theming}/.config/Kvantum/wabi";

        # -- Qt5ct (writable for theme_switcher) --
        "qt5ct/qt5ct.conf".source = mkOutOfStoreSymlink "${theming}/.config/qt5ct/qt5ct.conf";
        "qt5ct/style-colors.conf".source = mkOutOfStoreSymlink "${theming}/.config/qt5ct/style-colors.conf";
        "qt5ct/style-colors.conf.template".source = mkOutOfStoreSymlink "${theming}/.config/qt5ct/style-colors.conf.template";

        # -- Qt6ct (writable for theme_switcher) --
        "qt6ct/qt6ct.conf".source = mkOutOfStoreSymlink "${theming}/.config/qt6ct/qt6ct.conf";
        "qt6ct/style-colors.conf".source = mkOutOfStoreSymlink "${theming}/.config/qt6ct/style-colors.conf";
        "qt6ct/style-colors.conf.template".source = mkOutOfStoreSymlink "${theming}/.config/qt6ct/style-colors.conf.template";

        # -- Theme Switcher --
        "scripts/theme_switcher".source = mkOutOfStoreSymlink "${repo}/scripts/theme_switcher";

        # -- Color Schemes (writable for theme_switcher) --
        "color-schemes/Kvantum.colors.template".source = mkOutOfStoreSymlink "${theming}/.config/color-schemes/Kvantum.colors.template";

        # -- Fontconfig --
        "fontconfig/fonts.conf".source = mkOutOfStoreSymlink "${theming}/.config/fontconfig/fonts.conf";
      };

      home.sessionVariables = {
        QT_QPA_PLATFORMTHEME = "qt6ct";
        QT_STYLE_OVERRIDE = "kvantum";
        NIXPKGS_QT6_QML_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
      };

      home.activation.copyPapirusIcons = lib.mkAfter ''
        if [ ! -d "$HOME/.local/share/icons/Papirus-Dark" ]; then
          mkdir -p "$HOME/.local/share/icons"
          cp -rL ${pkgs.papirus-icon-theme}/share/icons/Papirus "$HOME/.local/share/icons/Papirus"
          cp -rL ${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark "$HOME/.local/share/icons/Papirus-Dark"
          chmod -R u+w "$HOME/.local/share/icons/Papirus"
          chmod -R u+w "$HOME/.local/share/icons/Papirus-Dark"
        fi
      '';
    };
  };
}
