{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFish = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.fish = {
      enable = true;
      interactiveShellInit = ''
        starship init fish | source
        zoxide init --cmd cd fish | source
      '';
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
      '';
      shellAbbrs = {
        g = "git";
        ga = "git add";
        gc = "git commit";
        gco = "git checkout";
        gd = "git diff";
        gl = "git log --oneline --graph --decorate -20";
        gp = "git push";
        gs = "git status";
        t = "tmux";
        ta = "tmux attach -t";
        tn = "tmux new-session -s";
        v = "nvim";
        c = "clear";
        lg = "lazygit";
      };
      functions = {
        tmu = {
          body = "tmux new-session -A -s monkie";
        };
      };
    };
  };
}
