{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  antigravityDir = "${repo}/modules/features/shell/antigravity";
in
{

  flake.nixosModules.parazeeknovaAntigravity =
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
            ".gemini/config/mcp_config.json".source = mkOutOfStoreSymlink "${antigravityDir}/mcp_config.json";
          };
        };
    };
}
