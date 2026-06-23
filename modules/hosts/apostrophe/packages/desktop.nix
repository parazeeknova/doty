{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      nerd-fonts.noto
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.victor-mono
    ];

    environment.systemPackages = with pkgs; [
      vivaldi
      vivaldi-ffmpeg-codecs

      # -- Thunar Supermacy --
      thunar
      thunar-volman
      thunar-archive-plugin
      thunar-vcs-plugin
      thunar-shares-plugin
      thunar-media-tags-plugin

      # -- Wayland / Hyprland --
      uwsm
      awww
      mpvpaper
      waybar
      hyprlock
      hypridle
      hyprshot
      hyprpicker
      hyprsunset
      hyprpaper
      pyprland
      quickshell
      grim
      slurp
      swappy
      wl-clipboard
      cliphist
      tesseract
      brightnessctl
      wlr-randr
      wl-gammactl
      matugen
      libnotify
      imagemagick

      # -- Audio / Media --
      playerctl
      imv
      mpv
      pavucontrol
      pamixer

      # -- System Tray / Applets --
      networkmanagerapplet
      blueman

      # -- Qt / GTK Themes --
      qt6Packages.qt6ct
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
      kdePackages.qtmultimedia
      qt5.qtmultimedia
      qt6.qtmultimedia
      qt6Packages.qtmultimedia
      libsForQt5.qtmultimedia
      papirus-icon-theme
      capitaine-cursors
      nwg-look

      # -- System Tools --
      udiskie
      lm_sensors

      # -- Security --
      seahorse
      gnome-keyring

      # -- Documents --
      zathura
      evince

      # -- Communication --
      vesktop
    ];
  };
}
