{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  zenDir = "${repo}/modules/features/applications/zen";
in
{

  flake.nixosModules.parazeeknovaZen =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        let
          inherit (config.lib.file) mkOutOfStoreSymlink;

          patched-zen =
            (pkgs.stdenv.mkDerivation {
              name = "zen-browser-patched";
              src = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight;

              nativeBuildInputs = [ pkgs.copyDesktopItems ];

              buildCommand = ''
                mkdir -p $out
                cp -rL $src/* $out/
                chmod -R u+w $out

                # Copy fx-autoconfig program files
                LIB_DIR=$(echo $out/lib/zen-bin-*)
                mkdir -p $LIB_DIR/defaults/pref
                cp ${./fx-autoconfig/program/config.js} $LIB_DIR/config.js
                cp ${./fx-autoconfig/program/defaults/pref/config-prefs.js} $LIB_DIR/defaults/pref/config-prefs.js
              '';
            })
            // {
              override = lib.setFunctionArgs (_: patched-zen) { cfg = true; };
            };
        in
        {
          imports = [
            inputs.zen-browser.homeModules.twilight
          ];

          programs.zen-browser = {
            enable = true;
            setAsDefaultBrowser = true;
            package = patched-zen;
          };

          xdg.configFile = {
            "zen/profiles.ini".source = mkOutOfStoreSymlink "${zenDir}/profiles.ini";
            "zen/user.js.template".source = mkOutOfStoreSymlink "${zenDir}/user.js.template";
            "zen/userChrome.css.template".source = mkOutOfStoreSymlink "${zenDir}/userChrome.css.template";
            "zen/userContent.css.template".source = mkOutOfStoreSymlink "${zenDir}/userContent.css.template";
            "zen/Profile Groups".source = mkOutOfStoreSymlink "${zenDir}/Profile Groups";
            "zen/fx-autoconfig".source = mkOutOfStoreSymlink "${zenDir}/fx-autoconfig";
            "zen/u7b24p71.Default Profile".source = mkOutOfStoreSymlink "${zenDir}/u7b24p71.Default Profile";
          };
        };
    };
}
