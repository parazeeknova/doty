{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  sattyDir = "${repo}/modules/features/wm/satty";
in
{

  flake.nixosModules.parazeeknovaSatty =
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
          home.packages = [ pkgs.satty ];

          xdg.configFile = {
            "satty/config.toml".source = mkOutOfStoreSymlink "${sattyDir}/config.toml";
            "satty/config.toml.template".source = mkOutOfStoreSymlink "${sattyDir}/config.toml.template";
          };
        };
    };
}
