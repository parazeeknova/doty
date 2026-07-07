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

      neo-browser = pkgs.appimageTools.wrapType2 {
        pname = "neo-browser";
        version = "2.0.6";
        src = appimageSrc;

        extraInstallCommands = ''
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/512x512/apps

          # Copy icon
          cp ${extractedSrc}/neo-browser.png $out/share/icons/hicolor/512x512/apps/neo-browser.png

          # Create desktop entry
          cat > $out/share/applications/neo-browser.desktop <<EOF
          [Desktop Entry]
          Name=Neo Browser
          Comment=Secure browser for online examinations
          Exec=neo-browser %U
          Icon=neo-browser
          Type=Application
          Categories=Utility;Network;WebBrowser;
          Terminal=false
          EOF
        '';
      };
    in
    {
      environment.systemPackages = [ neo-browser ];
    };
}
