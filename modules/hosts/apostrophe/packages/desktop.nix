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
          version = "3.3.6";
          src = fetchurl {
            url = "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.6/linux-x64/ZCode-3.3.6-linux-x64.AppImage";
            sha256 = "189zb8s867hp3q0l56a61nqx3xnack2r903vm71c6dz9ysyqdpp3";
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

        # -- Verso --
        (
          let
            verso-extracted = pkgs.stdenv.mkDerivation {
              pname = "verso-extracted";
              version = "0.3.78";
              src = /home/parazeeknova/Projects/verso/packages/native/artifacts/stable-linux-x64-Verso.tar.zst;
              dontBuild = true;
              dontConfigure = true;
              unpackPhase = ''
                mkdir -p temp
                ${pkgs.zstd}/bin/zstd -d -c $src | ${pkgs.gnutar}/bin/tar -xf - -C temp
              '';
              installPhase = ''
                mkdir -p $out/usr/bin
                mkdir -p $out/usr/lib
                cp -r temp/Verso/bin/* $out/usr/bin/
                cp -r temp/Verso/Resources $out/usr/bin/
                if [ -d temp/Verso/lib ]; then
                  cp -r temp/Verso/lib/* $out/usr/lib/
                fi
                ln -s bin/launcher $out/usr/bin/Verso
              '';
            };
          in
          pkgs.appimageTools.wrapAppImage {
            pname = "verso";
            version = "0.3.78";
            src = verso-extracted;
            extraPkgs =
              pkgs: with pkgs; [
                webkitgtk_4_1
                libsoup_3
                libayatana-appindicator
              ];
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              cat > $out/share/applications/verso.desktop <<EOF
              [Desktop Entry]
              Name=Verso
              Exec=verso %U
              Terminal=false
              Type=Application
              Icon=verso
              StartupWMClass=Verso
              Comment=Verso Application
              Categories=Network;
              EOF
            '';
          }
        )

        # -- Tldraw Offline --
        (pkgs.appimageTools.wrapType2 {
          pname = "tldraw-offline";
          version = "1.11.0";
          src = pkgs.fetchurl {
            url = "https://github.com/tldraw/tldraw-offline/releases/download/v1.11.0/tldraw-offline-linux-x86_64.AppImage";
            sha256 = "018f8irpd83swz4k3rr2aa5rd3073lhgnmsyc476inrkfrs0cj89";
          };
          extraInstallCommands = ''
            mkdir -p $out/share/applications
            cat > $out/share/applications/tldraw-offline.desktop <<EOF
            [Desktop Entry]
            Name=Tldraw Offline
            Exec=tldraw-offline %U
            Terminal=false
            Type=Application
            Icon=tldraw-offline
            StartupWMClass=tldraw-offline
            Comment=Collaborative digital whiteboard (offline)
            Categories=Graphics;
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
        kdePackages.qtstyleplugin-kvantum
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
