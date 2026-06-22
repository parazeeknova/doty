{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Browsers --
      firefox
      vivaldi

      # -- Editors (GUI) --
      vscode

      # -- Terminal Emulators --
      ghostty
      kitty

      # -- File Managers --
      thunar
      xfce.thunar-archive-plugin

      # -- Wayland / Hyprland --
      uwsm
      waybar
      hyprlock
      hypridle
      hyprshot
      hyprpicker
      hyprsunset
      pyprland
      quickshell
      swaylock
      swayidle
      grim
      slurp
      swappy
      wl-clipboard
      cliphist
      mako
      tesseract
      tesseract-data-eng

      # -- Media --
      playerctl
      imv
      mpv
      pavucontrol

      # -- Qt / GTK Themes --
      qt6Packages.qt6ct
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
      papirus-icon-theme
      papirus-folders
      capitaine-cursors

      # -- System Tools --
      udiskie
      lm_sensors
      pciutils

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
    ];
  };
}
