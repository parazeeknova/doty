{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

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
        vesktop
        telegram-desktop
        vivaldi
        vivaldi-ffmpeg-codecs

        # -- Thunar Helpers --
        file-roller

        # -- Wayland / Hyprland --
        uwsm
        pyprland
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
        spotify
        spicetify-cli
        wf-recorder
        vlc
        playerctl
        imv
        mpv
        pavucontrol
        pamixer
        pulseaudio

        # -- System Tray / Applets --
        networkmanagerapplet
        blueman

        # -- Qt / GTK Themes --
        qt6Packages.qt6ct
        libsForQt5.qt5ct
        libsForQt5.qtstyleplugin-kvantum
        kdePackages.qtmultimedia
        kdePackages.qtdeclarative
        qt5.qtmultimedia
        qt6.qtmultimedia
        qt6Packages.qtmultimedia
        qt5.qtdeclarative
        qt6.qtdeclarative
        libsForQt5.qtmultimedia
        papirus-icon-theme
        capitaine-cursors
        nwg-look

        # -- System Tools --
        udiskie
        lm_sensors
        upower

        # -- Security --
        seahorse
        gnome-keyring

        # -- Documents --
        zathura
        evince
      ];
    };
}
