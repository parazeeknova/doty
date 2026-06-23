{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  nvimDir = "${repo}/modules/features/shell/nvim";
in
{

  flake.nixosModules.parazeeknovaNvim = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "nvim/init.lua".source = mkOutOfStoreSymlink "${nvimDir}/init.lua";
        "nvim/init.lua.template".source = mkOutOfStoreSymlink "${nvimDir}/init.lua.template";
        "nvim/lazy-lock.json".source = mkOutOfStoreSymlink "${nvimDir}/lazy-lock.json";
        "nvim/lazyvim.json".source = mkOutOfStoreSymlink "${nvimDir}/lazyvim.json";
        "nvim/lua".source = mkOutOfStoreSymlink "${nvimDir}/lua";
        "nvim/stylua.toml".source = mkOutOfStoreSymlink "${nvimDir}/stylua.toml";
      };
    };
  };
}
