{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  swappyDir = "${repo}/modules/features/wm/swappy";
in
{

  flake.nixosModules.parazeeknovaSwappy =
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
            "swappy/config".source = mkOutOfStoreSymlink "${swappyDir}/config";
          };
        };
    };
}
