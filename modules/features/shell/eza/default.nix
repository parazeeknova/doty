{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  ezaDir = "${repo}/modules/features/shell/eza";
in
{

  flake.nixosModules.parazeeknovaEza = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      programs.eza = {
        enable = true;
        enableFishIntegration = false;
        enableBashIntegration = false;
      };

      xdg.configFile = {
        "eza/theme.yml".source = mkOutOfStoreSymlink "${ezaDir}/theme.yml";
        "eza/theme.yml.template".source = mkOutOfStoreSymlink "${ezaDir}/theme.yml.template";
      };
    };
  };
}
