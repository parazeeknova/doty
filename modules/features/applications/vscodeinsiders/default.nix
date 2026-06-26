{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  vscodeInsidersDir = "${repo}/modules/features/applications/vscodeinsiders";
in
{

  flake.nixosModules.parazeeknovaVscodeinsiders =
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
          home.file.".config/Code - Insiders/User/settings.json".source =
            mkOutOfStoreSymlink "${vscodeInsidersDir}/settings.json";

          home.file.".vscode-insiders/extensions".source =
            mkOutOfStoreSymlink "/home/parazeeknova/.vscode/extensions";
        };
    };
}
