{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  mpdDir = "${repo}/modules/features/shell/mpd";
in
{

  flake.nixosModules.parazeeknovaMpd = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      home.packages = [ pkgs.mpd ];

      xdg.configFile = {
        "mpd/mpd.conf".source = mkOutOfStoreSymlink "${mpdDir}/mpd.conf";
      };
    };
  };
}
