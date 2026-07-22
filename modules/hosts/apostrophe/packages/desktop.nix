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
          version = "3.4.2";
          src = fetchurl {
            url = "https://cdn-zcode.z.ai/zcode/electron/releases/3.4.2/linux-x64/ZCode-3.4.2-linux-x64.AppImage";
            sha256 = "0ip9vcif5zklskn0h3n12w56qkqgj52piprf2q5zmscpp14q91lx";
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

        # -- OpenCode Desktop --
        (stdenv.mkDerivation rec {
          pname = "opencode-desktop";
          version = "1.18.4";

          src = fetchurl {
            url = "https://opencode.ai/download/stable/linux-x64-deb";
            sha256 = "16b59lml6l0lm4nj6lndjrcvb034w6ijzwx8wxsh5lfyk1xc8yx6";
          };

          nativeBuildInputs = [
            dpkg
            autoPatchelfHook
            makeWrapper
          ];

          buildInputs = [
            alsa-lib
            at-spi2-atk
            at-spi2-core
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk-pixbuf
            glib
            gtk3
            libGL
            libappindicator-gtk3
            libdrm
            libnotify
            libpulseaudio
            libsecret
            libuuid
            libxkbcommon
            mesa
            nspr
            nss
            pango
            systemd
            wayland
            xorg.libX11
            xorg.libXcomposite
            xorg.libXcursor
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXi
            xorg.libXrandr
            xorg.libXrender
            xorg.libXtst
            xorg.libxcb
            xorg.libxshmfence
          ];

          unpackPhase = ''
            dpkg-deb -x $src .
          '';

          installPhase = ''
            mkdir -p $out/opt $out/bin $out/share

            cp -r opt/OpenCode $out/opt/opencode
            cp -r usr/share/* $out/share/

            # Remove unused musl node native modules to avoid patchelf errors
            find $out/opt/opencode -name "*musl*" -exec rm -rf {} + || true

            chmod +x $out/opt/opencode/ai.opencode.desktop

            makeWrapper $out/opt/opencode/ai.opencode.desktop $out/bin/opencode-desktop \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
              --add-flags "--no-sandbox"

            mkdir -p $out/share/applications
            cat > $out/share/applications/opencode-desktop.desktop <<EOF
            [Desktop Entry]
            Name=OpenCode Desktop
            Exec=opencode-desktop %U
            Terminal=false
            Type=Application
            Icon=ai.opencode.desktop
            StartupWMClass=ai.opencode.desktop
            Comment=Open source AI coding agent
            Categories=Development;
            EOF
          '';

          preFixup = ''
            autoPatchelfIgnoreMissing=(libc.musl-x86_64.so.1)
          '';
        })


        # -- Verso --
        (
          let
            verso-extracted = pkgs.appimageTools.extractType2 {
              pname = "verso";
              version = "0.4.26";
              src = pkgs.fetchurl {
                url = "https://github.com/parazeeknova/verso/releases/download/v0.4.26/Verso-0.4.26-x86_64.AppImage";
                sha256 = "1w0cgrqywn06363x11jws97pdadbdzr55gdsnnq4p3lmjvaprdh5";
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
            version = "0.4.26";
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
