{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  pyprDir = "${repo}/modules/features/wm/pypr";
in
{

  flake.nixosModules.parazeeknovaPypr =
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
          home.packages = [ pkgs.pyprland ];

          xdg.configFile = {
            "pypr/config.toml".source = mkOutOfStoreSymlink "${pyprDir}/config.toml";
          };
        };
    };
}
