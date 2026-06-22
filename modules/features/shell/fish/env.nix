{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishEnv = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.fish = {
      shellInit = ''
        set -gx LANG en_US.UTF-8
        set -gx LC_ALL en_US.UTF-8
        set -gx GPG_TTY (tty)
        set -gx SSH_ASKPASS /usr/lib/seahorse/ssh-askpass
        set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
        set -gx PATH $HOME/.npm-global/bin $PATH
        set -x MANROFFOPT -c
        set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
        set -U __done_min_cmd_duration 10000
        set -U __done_notification_urgency_level low
        export PATH="$HOME/.bun/bin:$PATH"
        export DOCKER_COMPOSE_PROVIDER_WARNING=0
        fish_add_path ~/.local/bin
        fish_add_path ~/.cargo/bin
        fish_add_path ~/Applications/depot_tools
        fish_add_path ~/.spicetify
        fish_add_path ~/.bun/bin
        fish_add_path ~/.lmstudio/bin
        fish_add_path /home/parazeeknova/.mimocode/bin
        set -Ux WABI_DOTFILES_DIR "$HOME/doty"
        set -Ux WABI_VM_SCAN_ROOT "/run/media/parazeeknova/clips/VM"
        set -Ux WABI_GITHUB_USER "parazeeknova"
        set -Ux WABI_PRESETS_DIR "$HOME/doty/.config/hypr/wabi/presets"
        set --query XDG_DATA_HOME || set --local XDG_DATA_HOME ~/.local/share
        set --query nvm_mirror || set --global nvm_mirror https://nodejs.org/dist
        set --query nvm_data || set --global nvm_data $XDG_DATA_HOME/nvm
      '';
    };
  };
}
