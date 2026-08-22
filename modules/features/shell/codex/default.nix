{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  codexDir = "${repo}/modules/features/shell/codex";
in
{

  flake.nixosModules.parazeeknovaCodex =
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
          home.file = {
            ".codex/config.toml".source = mkOutOfStoreSymlink "${codexDir}/config.toml";
          };
        };
    };
}
