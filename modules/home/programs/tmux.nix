{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaTmux = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      baseIndex = 1;
      escapeTime = 0;
      mouse = true;
      keyMode = "vi";
      prefix = "C-b";
      extraConfig = ''
        set -ag terminal-overrides ",xterm-256color:RGB"

        set-option -g prefix2 C-s

        unbind r
        bind r source-file ~/.config/tmux/tmux.conf

        unbind %
        bind | split-window -h -c "#{pane_current_path}"

        unbind '"'
        bind - split-window -v -c "#{pane_current_path}"

        unbind v
        bind v copy-mode

        bind -r j resize-pane -D 5
        bind -r k resize-pane -U 5
        bind -r l resize-pane -R 5
        bind -r h resize-pane -L 5

        bind -r m resize-pane -Z

        bind-key -T copy-mode-vi 'v' send -X begin-selection
        bind-key -T copy-mode-vi 'y' send -X copy-selection

        bind-key -r f run-shell "tmux neww ~/scripts/tmux-sessionizer"
        bind-key n command-prompt "new-session -s '%%'"

        bind-key C-y display-popup -d "#{pane_current_path}" -w 90% -h 90% -E "yazi"
        bind-key C-t display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "fish"
        bind-key C-g display-popup -d "#{pane-current-path}" -w 90% -h 90% -E "lazygit"

        unbind -T copy-mode-vi MouseDragEnd1Pane

        set -g status-position top
        set -g status-justify right

        setw -g pane-border-status off
        setw -g pane-border-format ""
        setw -g pane-border-lines simple

        set -wg automatic-rename on
        set -g automatic-rename-format "#{pane_current_command}"
      '';
      plugins = with pkgs; [
        tmuxPlugins.vim-tmux-navigator
        tmuxPlugins.catppuccin
      ];
    };
  };
}
