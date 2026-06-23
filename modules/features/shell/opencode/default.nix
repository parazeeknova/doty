{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  opencodeDir = "${repo}/modules/features/shell/opencode";
in
{

  flake.nixosModules.parazeeknovaOpencode =
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
        in
        {
          xdg.configFile = {
            "opencode/opencode.json".source = mkOutOfStoreSymlink "${opencodeDir}/opencode.json";
            "opencode/tui.json".source = mkOutOfStoreSymlink "${opencodeDir}/tui.json";
            "opencode/themes".source = mkOutOfStoreSymlink "${opencodeDir}/themes";
          };
        };
    };
}
