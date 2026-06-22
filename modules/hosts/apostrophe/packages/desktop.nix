{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- General --
      vivaldi
      vscode
      kitty

      # -- Hyprland --
      waybar
      wofi
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      cliphist
      mako
      hyprshot
      hyprpicker

      # -- Qt / GTK Themes --
      qt6Packages.qt6ct
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
      papirus-icon-theme
      papirus-folders
      capitaine-cursors

      # -- Fonts --
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      nerd-fonts.noto
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.victor-mono
    ];
  };
}
