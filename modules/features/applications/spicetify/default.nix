{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  spicetifyDir = "${repo}/modules/features/applications/spicetify";
in
{

  flake.nixosModules.parazeeknovaSpicetify = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "spicetify/Themes".source = mkOutOfStoreSymlink "${spicetifyDir}/Themes";
      };
    };
  };
}
