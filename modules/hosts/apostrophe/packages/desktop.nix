{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

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
      mako
      tesseract
      brightnessctl
      wlr-randr
      wl-gammactl

      # -- Audio / Media --
      playerctl
      imv
      mpv
      pavucontrol
      pamixer
      cava

      # -- System Tray / Applets --
      networkmanagerapplet
      blueman

      # -- Qt / GTK Themes --
      qt6Packages.qt6ct
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
      papirus-icon-theme
      papirus-folders
      capitaine-cursors
      nwg-look

      # -- System Tools --
      udiskie
      lm_sensors

      # -- Security --
      seahorse
      gnome-keyring

      # -- Fonts --
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      nerd-fonts.noto
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.victor-mono

      # -- Documents --
      zathura
      evince

      # -- Communication --
      vesktop
    ];
  };
}
