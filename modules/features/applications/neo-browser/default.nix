{ self, inputs, ... }:

{
  flake.nixosModules.parazeeknovaNeoBrowser =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      appimageSrc = pkgs.requireFile {
        name = "Neo-Browser-2.0.6.AppImage";
        sha256 = "0fq4ycc978r76z28hbsqzavmsn1pnl0mf97k8h8d7477wiskg60d";
        url = "file:///home/parazeeknova/app-images/Neo-Browser-2.0.6.AppImage";
      };

      extractedSrc = pkgs.appimageTools.extract {
        pname = "neo-browser";
        version = "2.0.6";
        src = appimageSrc;
      };

      neo-browser = pkgs.stdenv.mkDerivation {
        pname = "neo-browser";
        version = "2.0.6";

        src = extractedSrc;

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.wrapGAppsHook3
          pkgs.copyDesktopItems
          pkgs.makeWrapper
        ];

        buildInputs = with pkgs; [
          glib
          nss
          nspr
          dbus
          atk
          at-spi2-core
          cups
          gtk3
          pango
          cairo
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          mesa
          expat
          libxcb
          libxkbcommon
          systemd
          alsa-lib
          libglvnd
        ];

        # Tell autoPatchelf not to complain about libraries it can't find that might not be needed
        autoPatchelfIgnoreMissingDeps = true;

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib/neo-browser
          mkdir -p $out/share/icons/hicolor/512x512/apps

          # Copy extracted files to the lib directory
          cp -r * $out/lib/neo-browser/

          # Make the binary executable
          chmod +x $out/lib/neo-browser/neo-browser

          # Symlink it to bin/
          ln -s $out/lib/neo-browser/neo-browser $out/bin/neo-browser

          # Copy icon
          cp $out/lib/neo-browser/neo-browser.png $out/share/icons/hicolor/512x512/apps/neo-browser.png
        '';

        postFixup = ''
          wrapProgram $out/bin/neo-browser \
            --prefix LD_LIBRARY_PATH : ${
              lib.makeLibraryPath [
                pkgs.libGL
                pkgs.libglvnd
              ]
            }
        '';

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "neo-browser";
            exec = "neo-browser %U";
            icon = "neo-browser";
            desktopName = "Neo Browser";
            comment = "Secure browser for online examinations";
            categories = [
              "Utility"
              "Network"
              "WebBrowser"
            ];
            mimeType = [ "x-scheme-handler/neoexam" ];
            terminal = false;
          })
        ];
      };
    in
    {
      environment.systemPackages = [ neo-browser ];
    };
}
