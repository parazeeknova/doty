{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  nvimDir = "${repo}/modules/features/shell/nvim/config";
in
{

  flake.nixosModules.parazeeknovaNvim =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.users.parazeeknova =
        { config, pkgs, lib, ... }:
        let
          inherit (config.lib.file) mkOutOfStoreSymlink;
        in
        {
          xdg.configFile = {
            "nvim".source = mkOutOfStoreSymlink nvimDir;
          };

          home.packages = with pkgs; [
            git
            tree-sitter
            gnumake
            (lib.lowPrio gcc)
            llvmPackages.clang
            clang-tools
            lua-language-server
            nodejs
            ripgrep
            fd
            stylua
            prettierd
            biome
            imagemagick
            xclip
            wl-clipboard
          ];
        };
    };
}
