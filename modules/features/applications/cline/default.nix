{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaCline =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cline = pkgs.stdenv.mkDerivation rec {
        pname = "cline";
        version = "0.0.41";

        src = pkgs.fetchurl {
          url = "https://github.com/cline/cline/releases/download/desktop-v${version}/Cline_${version}_amd64.deb";
          sha256 = "1y7pf62m53vgk2nbdjwfmbz4ic9pj5bkmz3c8ici48749az06vzy";
        };

        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
          wrapGAppsHook3
        ];

        buildInputs = with pkgs; [
          gtk3
          webkitgtk_4_1
          libsoup_3
          libayatana-appindicator
          cairo
          gdk-pixbuf
          glib
          glib-networking
          dbus
          openssl
          stdenv.cc.cc.lib
        ];

        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x $src .
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out
          cp -r usr/* $out/

          ln -s $out/bin/cline-app $out/bin/cline

          runHook postInstall
        '';

        preFixup = ''
          gappsWrapperArgs+=(
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libayatana-appindicator ]}"
            --set CLINE_CODE_SIDECAR_BIN "$out/bin/code-sidecar"
          )
        '';

        meta = {
          description = "Cline Desktop - AI coding agent";
          homepage = "https://github.com/cline/cline";
          platforms = [ "x86_64-linux" ];
          mainProgram = "cline-app";
        };
      };
    in
    {
      environment.systemPackages = [ cline ];
    };
}
