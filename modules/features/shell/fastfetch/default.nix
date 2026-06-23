{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  fastfetchDir = "${repo}/modules/features/shell/fastfetch";
in
{

  flake.nixosModules.parazeeknovaFastfetch =
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
          programs.fastfetch = {
            enable = true;
          };

          xdg.configFile = {
            "fastfetch/config.jsonc".source = mkOutOfStoreSymlink "${fastfetchDir}/config.jsonc";
            "fastfetch/config.jsonc.template".source =
              mkOutOfStoreSymlink "${fastfetchDir}/config.jsonc.template";
            "fastfetch/cat.txt".source = mkOutOfStoreSymlink "${fastfetchDir}/cat.txt";
          };
        };
    };
}
