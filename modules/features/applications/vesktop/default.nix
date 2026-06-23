{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  vesktopDir = "${repo}/modules/features/applications/vesktop";
in
{

  flake.nixosModules.parazeeknovaVesktop =
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
            "vesktop/settings".source = mkOutOfStoreSymlink "${vesktopDir}/settings";
          };
        };
    };
}
