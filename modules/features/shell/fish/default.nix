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
        set -Ux WABI_DOTFILES_DIR "$HOME/doty"
        set -Ux WABI_VM_SCAN_ROOT "/run/media/parazeeknova/clips/VM"
        set -Ux WABI_GITHUB_USER "parazeeknova"
        set -Ux WABI_PRESETS_DIR "$HOME/doty/.config/hypr/wabi/presets"
        set --query XDG_DATA_HOME || set --local XDG_DATA_HOME ~/.local/share
        set --query nvm_mirror || set --global nvm_mirror https://nodejs.org/dist
        set --query nvm_data || set --global nvm_data $XDG_DATA_HOME/nvm
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
        fish_greeting = {
          body = "";
        };
        __ssh_agent_start = {
          body = ''
            if not pgrep -u (id -u) ssh-agent >/dev/null
                eval (ssh-agent -c) >/dev/null
                set -Ux SSH_AGENT_PID $SSH_AGENT_PID
                set -Ux SSH_AUTH_SOCK $SSH_AUTH_SOCK
            end
          '';
        };
        ssh = {
          wraps = "ssh";
          body = ''
            __ssh_agent_start
            command ssh $argv
          '';
        };
        git = {
          wraps = "git";
          body = ''
            __ssh_agent_start
            command git $argv
          '';
        };
        __history_previous_command = {
          body = ''
            switch (commandline -t)
                case "!"
                    commandline -t $history[1]
                    commandline -f repaint
                case "*"
                    commandline -i !
            end
          '';
        };
        __history_previous_command_arguments = {
          body = ''
            switch (commandline -t)
                case "!"
                    commandline -t ""
                    commandline -f history-token-search-backward
                case "*"
                    commandline -i '$'
            end
          '';
        };
        history = {
          wraps = "history";
          body = "builtin history --show-time='%F %T '";
        };
        backup = {
          body = "cp $argv[1] $argv[1].bak";
        };
        copy = {
          body = ''
            set count (count $argv | tr -d \\n)
            if test "$count" = 2; and test -d "$argv[1]"
                set from (echo $argv[1] | trim-right /)
                set to (echo $argv[2])
                command cp -r $from $to
            else
                command cp $argv
            end
          '';
        };
        gl = {
          body = "git log --all --graph --pretty=format:'%C(magenta)%h %C(white) %an %ar%C(auto) %D%n%s%n'";
        };
        gc = {
          body = ''
            if test (count $argv) -eq 0
                git commit
            else
                git commit -m (string join " " $argv)
            end
            echo
            git status --short
          '';
        };
        gac = {
          body = ''
            git add .
            git status --short
            echo -n "Commit message: "
            read msg
            if test -n "$msg"
                git commit -m "$msg"
                git push
            else
                echo "Cancelled: Commit message cannot be empty."
            end
          '';
        };
      };
      interactiveShellAbbrs = {
        "!!" = "__history_previous_command";
        "!$" = "__history_previous_command_arguments";
      };
    };
  };
}
