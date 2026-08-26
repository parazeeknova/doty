{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  claudeDir = "${repo}/modules/features/shell/claude";
in
{
  flake.nixosModules.parazeeknovaClaude =
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
            ".claude/themes/matugen.json".source = mkOutOfStoreSymlink "${claudeDir}/themes/matugen.json";
            ".claude/themes/matugen.json.template".source = mkOutOfStoreSymlink "${claudeDir}/themes/matugen.json.template";
          };
        };
    };
}
