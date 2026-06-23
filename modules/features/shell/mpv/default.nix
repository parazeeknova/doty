{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  mpvDir = "${repo}/modules/features/shell/mpv";
in
{

  flake.nixosModules.parazeeknovaMpv = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "mpv/mpv.conf".source = mkOutOfStoreSymlink "${mpvDir}/mpv.conf";
        "mpv/mpv.conf.template".source = mkOutOfStoreSymlink "${mpvDir}/mpv.conf.template";
      };
    };
  };
}
