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
        {
          programs.vscode = {
            enable = true;
            package = pkgs.vscode-insiders;
            profiles.default.userSettings = builtins.fromJSON (builtins.readFile ./settings.json);
          };
        };
    };
}
