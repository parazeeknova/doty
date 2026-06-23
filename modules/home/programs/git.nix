{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  gitDir = "${repo}/modules/home/programs/git";
in
{

  flake.nixosModules.parazeeknovaGit = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      home.packages = [ pkgs.git pkgs.git-lfs ];

      xdg.configFile = {
        "git/config".source = mkOutOfStoreSymlink "${gitDir}/config";
        "git/colors".source = mkOutOfStoreSymlink "${gitDir}/colors";
        "git/colors.template".source = mkOutOfStoreSymlink "${gitDir}/colors.template";
        "git/ignore".source = mkOutOfStoreSymlink "${gitDir}/ignore";
        "git/attributes".source = mkOutOfStoreSymlink "${gitDir}/attributes";
      };
    };
  };
}
