{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Browsers --
      firefox
      vivaldi
      zen-browser

      # -- Editors (GUI) --
      vscode

      # -- Terminal Emulators --
      ghostty
      kitty

      # -- File Managers --
      thunar
      xfce.thunar-archive-plugin
      xfce.thunar-volman

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
      swaylock
      swayidle
      swaybg
      grim
      slurp
      swappy
      wl-clipboard
      cliphist
      mako
      tesseract
      tesseract-data-eng
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
      brightnessctl

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
      pciutils
      htop
      btop

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
      libreoffice

      # -- Communication --
      vesktop
      signal-desktop
      telegram-desktop
    ];
  };
}
