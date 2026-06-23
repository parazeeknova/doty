{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  lazygitDir = "${repo}/modules/features/shell/lazygit";
in
{

  flake.nixosModules.parazeeknovaLazygit = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "lazygit/config.yml".source = mkOutOfStoreSymlink "${lazygitDir}/config.yml";
        "lazygit/config.yml.template".source = mkOutOfStoreSymlink "${lazygitDir}/config.yml.template";
      };
    };
  };
}
