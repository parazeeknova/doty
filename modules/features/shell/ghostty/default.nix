{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  ghosttyDir = "${repo}/modules/features/shell/ghostty";
in
{

  flake.nixosModules.parazeeknovaGhostty = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "ghostty/config".source = mkOutOfStoreSymlink "${ghosttyDir}/config";
        "ghostty/theme.template".source = mkOutOfStoreSymlink "${ghosttyDir}/theme.template";
        "ghostty/shaders".source = mkOutOfStoreSymlink "${ghosttyDir}/shaders";
        "ghostty/themes".source = mkOutOfStoreSymlink "${ghosttyDir}/themes";
      };
    };
  };
}
