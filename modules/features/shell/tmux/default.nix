{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  tmuxDir = "${repo}/modules/features/shell/tmux";
in
{

  flake.nixosModules.parazeeknovaTmux =
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
          xdg.configFile = {
            "tmux/tmux.conf".source = mkOutOfStoreSymlink "${tmuxDir}/tmux.conf";
            "tmux/tmux.conf.template".source = mkOutOfStoreSymlink "${tmuxDir}/tmux.conf.template";
            "tmux/.tmux".source = mkOutOfStoreSymlink "${tmuxDir}/.tmux";
          };
        };
    };
}
