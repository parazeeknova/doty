{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  matugenDir = "${repo}/modules/features/wm/matugen";
in
{

  flake.nixosModules.parazeeknovaMatugen =
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
            "matugen/config.toml".source = mkOutOfStoreSymlink "${matugenDir}/config.toml";
            "matugen/templates".source = mkOutOfStoreSymlink "${matugenDir}/templates";
          };
        };
    };
}
