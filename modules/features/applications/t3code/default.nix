{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaT3Code =
    { pkgs, ... }:
    let
      t3code = pkgs.appimageTools.wrapType2 rec {
        pname = "t3code";
        version = "0.0.42";

        src = pkgs.fetchurl {
          url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
          sha256 = "1x6dwfb5yp9hxmihj720a69ip4qixxrcfk4lldckmvf2mg6zrhcd";
        };

        extraInstallCommands = ''
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/512x512/apps
          cp -r ${
            pkgs.appimageTools.extract { inherit pname version src; }
          }/usr/share/icons/hicolor/512x512/apps/* $out/share/icons/hicolor/512x512/apps/
          cat > $out/share/applications/t3code.desktop <<EOF
          [Desktop Entry]
          Name=T3 Code
          Exec=t3code --no-sandbox %U
          Terminal=false
          Type=Application
          Icon=t3code
          StartupWMClass=t3code
          Comment=T3 Code - AI Agent Harness Control Surface
          MimeType=x-scheme-handler/t3code;x-scheme-handler/t3code-dev;
          Categories=Development;
          EOF
        '';
      };
    in
    {
      environment.systemPackages = [
        t3code
      ];
    };
}
