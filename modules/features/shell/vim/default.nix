{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  vimDir = "${repo}/modules/features/shell/vim";
in
{

  flake.nixosModules.parazeeknovaVim = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "vim/vimrc".source = mkOutOfStoreSymlink "${vimDir}/vimrc";
        "vim/wabi.vim".source = mkOutOfStoreSymlink "${vimDir}/wabi.vim";
        "vim/colors".source = mkOutOfStoreSymlink "${vimDir}/colors";
      };
    };
  };
}
