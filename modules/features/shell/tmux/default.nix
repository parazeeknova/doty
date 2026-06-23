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
          programs.tmux = {
            enable = true;
            plugins = with pkgs.tmuxPlugins; [
              cpu
              yank
              battery
              continuum
              resurrect
              catppuccin
              sessionist
              tmux-floax
              online-status
              tmux-sessionx
              vim-tmux-navigator
            ];
            extraConfig = ''
              source-file ${tmuxDir}/tmux.conf
            '';
          };

          xdg.configFile = {
            "tmux/tmux.conf.template".source = mkOutOfStoreSymlink "${tmuxDir}/tmux.conf.template";
            "tmux/.tmux".source = mkOutOfStoreSymlink "${tmuxDir}/.tmux";
          };
        };
    };
}
