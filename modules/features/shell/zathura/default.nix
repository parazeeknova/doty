{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  zathuraDir = "${repo}/modules/features/shell/zathura";
in
{

  flake.nixosModules.parazeeknovaZathura = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      programs.zathura = {
        enable = true;
      };

      xdg.configFile = {
        "zathura/zathurarc".source = mkOutOfStoreSymlink "${zathuraDir}/zathurarc";
        "zathura/zathurarc.template".source = mkOutOfStoreSymlink "${zathuraDir}/zathurarc.template";
      };
    };
  };
}
