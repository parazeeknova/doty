{ self, inputs, ... }:

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
          repo = "${config.home.homeDirectory}/doty";
          vscodeInsidersDir = "${repo}/modules/features/applications/vscodeinsiders";
        in
        {
          home.file.".config/Code - Insiders/User/settings.json".source =
            mkOutOfStoreSymlink "${vscodeInsidersDir}/settings.json";

          home.file.".config/Code/User/settings.json".source =
            mkOutOfStoreSymlink "${vscodeInsidersDir}/settings.json";

          home.file.".vscode-insiders/extensions".source =
            mkOutOfStoreSymlink "${config.home.homeDirectory}/.vscode/extensions";
        };
    };
}
