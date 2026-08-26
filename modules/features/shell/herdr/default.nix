{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  herdrDir = "${repo}/modules/features/shell/herdr";
in
{
  flake.nixosModules.parazeeknovaHerdr =
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
            "herdr/config.toml".source = mkOutOfStoreSymlink "${herdrDir}/config.toml";
            "herdr/config.toml.template".source = mkOutOfStoreSymlink "${herdrDir}/config.toml.template";
          };
        };
    };
}
