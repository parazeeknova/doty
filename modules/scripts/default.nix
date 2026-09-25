{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  scriptsDir = "${repo}/modules/scripts";
in
{

  flake.nixosModules.parazeeknovaScripts =
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

          lcc-bin = pkgs.writeShellScriptBin "lcc" ''
            exec ${scriptsDir}/lcc "$@"
          '';

          mg-key-picker-bin = pkgs.writeShellScriptBin "mg-key-picker" ''
            exec ${scriptsDir}/mg-key-picker "$@"
          '';
        in
        {
          home.packages = [
            lcc-bin
            mg-key-picker-bin
          ];

          home.file = {
            "scripts/mg-key-picker".source = mkOutOfStoreSymlink "${scriptsDir}/mg-key-picker";
            "scripts/lcc".source = mkOutOfStoreSymlink "${scriptsDir}/lcc";
            "scripts/kbd_aura".source = mkOutOfStoreSymlink "${scriptsDir}/kbd_aura";
            "scripts/presets_lister".source = mkOutOfStoreSymlink "${scriptsDir}/presets_lister";
            "scripts/set_wallpaper".source = mkOutOfStoreSymlink "${scriptsDir}/set_wallpaper";
            "scripts/set_wallpaper_bin".source = mkOutOfStoreSymlink "${scriptsDir}/set_wallpaper_bin";
            "scripts/theme_switcher".source = mkOutOfStoreSymlink "${scriptsDir}/theme_switcher";
            "scripts/tmux-sessionizer".source = mkOutOfStoreSymlink "${scriptsDir}/tmux-sessionizer";
            "scripts/toggle_wallpaper_pause".source =
              mkOutOfStoreSymlink "${scriptsDir}/toggle_wallpaper_pause";
            "scripts/mako_mode".source = mkOutOfStoreSymlink "${scriptsDir}/mako_mode";
            "scripts/layout_mode_switch".source = mkOutOfStoreSymlink "${scriptsDir}/layout_mode_switch";
          };
        };
    };
}
