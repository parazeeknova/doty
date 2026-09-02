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
        vivaldi
        vivaldi-ffmpeg-codecs
        inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
        vesktop
        telegram-desktop
        phototonic

        # -- Verso --
        (
          let
            verso-extracted = pkgs.appimageTools.extract {
              pname = "verso";
              version = "0.7.45";
              src = pkgs.fetchurl {
                url = "https://github.com/parazeeknova/amemorymachine/releases/download/v0.7.45/Verso-0.7.45-x86_64.AppImage";
                sha256 = "02779kb9gsl4sy8rwmz6fi3f18drc1gmn19zkldvn4w9szr0wif6";
              };
              postExtract = ''
                # Extract the embedded Electrobun tarball into a temp directory
                mkdir temp_extract
                tar_zst=$(find $out -name "*.tar.zst")
                if [ -n "$tar_zst" ]; then
                  chmod +w -R $out
                  ${pkgs.zstd}/bin/zstd -d -c "$tar_zst" | ${pkgs.gnutar}/bin/tar -xf - -C temp_extract
                  cp -r temp_extract/Verso/* $out/usr/bin/
                  rm -rf temp_extract
                  ln -s bin/launcher $out/usr/bin/Verso
                else
                  echo "Error: no .tar.zst archive found inside the AppImage!"
                  exit 1
                fi
              '';
            };
          in
          pkgs.appimageTools.wrapAppImage {
            pname = "verso";
            version = "0.7.45";
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
          version = "1.15.0";
          src = pkgs.fetchurl {
            url = "https://github.com/tldraw/tldraw-offline/releases/download/v1.15.0/tldraw-offline-linux-x86_64.AppImage";
            sha256 = "1623p6w1s502wb465qh0f0g51djhc86kx22dm9z3hgxcym2a0x04";
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

        # -- Cap --
        (pkgs.stdenv.mkDerivation rec {
          pname = "cap";
          version = "0.5.9";

          src = pkgs.fetchurl {
            url = "https://cdn.crabnebula.app/asset/01KZEFJYCGN6YJ32PQ7AX334RZ";
            sha256 = "1hkc4k143ls605m395p5iqx2rbif3qi76qw608k8d75vs6cyqz70";
          };

          nativeBuildInputs = with pkgs; [
            dpkg
            autoPatchelfHook
            wrapGAppsHook3
          ];

          buildInputs = with pkgs; [
            webkitgtk_4_1
            gtk3
            cairo
            gdk-pixbuf
            glib
            libsoup_3
            libayatana-appindicator
            pipewire
            alsa-lib
            openssl
            libx11
            libxkbcommon
            libva
            libpulseaudio
            stdenv.cc.cc.lib
          ];

          unpackPhase = ''
            dpkg-deb -x $src .
          '';

          installPhase = ''
            mkdir -p $out
            cp -r usr/* $out/
            ln -s $out/bin/Cap $out/bin/cap
          '';
        })

        # -- Multi Media --
        freetube
        vlc
        obs-studio
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

        # -- Security --
        seahorse
        gnome-keyring

        # -- Documents --
        zathura
        zathuraPkgs.zathura_pdf_mupdf
      ];
    };
}
