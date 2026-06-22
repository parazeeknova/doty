{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishFunctions = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.fish = {
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
      interactiveShellInit = ''
        if [ "$fish_key_bindings" = fish_vi_key_bindings ]
            bind -Minsert ! __history_previous_command
            bind -Minsert '$' __history_previous_command_arguments
        else
            bind ! __history_previous_command
            bind '$' __history_previous_command_arguments
        end
      '';
    };
  };
}
