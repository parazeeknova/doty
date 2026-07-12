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
        # -- Web --
        google-chrome
        megasync
        chromium
        vivaldi
        vivaldi-ffmpeg-codecs
        inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
        vesktop
        telegram-desktop
        localsend
        phototonic

        # -- ZCode --
        (appimageTools.wrapType2 {
          pname = "zcode";
          version = "3.3.4";
          src = fetchurl {
            url = "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/ZCode-3.3.4-linux-x64.AppImage";
            sha256 = "1sj1x4iinhyilnxr5cyx5myifvnhkpq1n2j4d6xl0cy2pfv2y1fi";
          };
          extraInstallCommands = ''
            mkdir -p $out/share/applications
            cat > $out/share/applications/zcode.desktop <<EOF
            [Desktop Entry]
            Name=ZCode
            Exec=zcode %U
            Terminal=false
            Type=Application
            Icon=zcode
            StartupWMClass=ZCode
            Comment=AI Coding Assistant
            Categories=Development;
            EOF
          '';
        })

        # -- Multi Media --
        freetube
        audacity
        blender
        vlc
        krita
        gimp
        inkscape
        obs-studio
        kdePackages.kdenlive
        ncmpcpp
        qbittorrent-enhanced

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
        file-roller

        # -- Audio / Media --
        spotify
        spicetify-cli
        wf-recorder
        playerctl
        imv
        mpv
        pavucontrol
        pamixer
        pulseaudio

        # -- System Tray / Apps --
        networkmanagerapplet
        blueman
        gnome-calculator
        gnome-clocks

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
        kdePackages.ark
        gnome-disk-utility

        # -- Security --
        seahorse
        gnome-keyring

        # -- Documents --
        zathura
        zathuraPkgs.zathura_pdf_mupdf
        evince
        onlyoffice-desktopeditors
      ];
    };
}
