{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHome = { config, pkgs, lib, ... }: {

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.parazeeknova = { ... }: {
        imports = [
          self.homeManagerModules.parazeeknovaGit
          self.homeManagerModules.parazeeknovaFish
          self.homeManagerModules.parazeeknovaStarship
          self.homeManagerModules.parazeeknovaTmux
          self.homeManagerModules.parazeeknovaZoxide
        ];

        home = {
          username = "parazeeknova";
          homeDirectory = "/home/parazeeknova";
          stateVersion = "24.11";
        };

        programs.home-manager.enable = true;
      };
    };
  };

  flake.homeManagerModules.parazeeknovaGit = { pkgs, lib, ... }: {
    programs.git = {
      enable = true;
      userName = "Harsh Sahu";
      userEmail = "yesh8harsh+github@gmail.com";
      signing = {
        signByDefault = true;
        key = "/home/parazeeknova/.ssh/github_signing_key.pub";
      };
      extraConfig = {
        core = {
          compression = 9;
          whitespace = "error";
          preloadindex = true;
        };
        advice = {
          addEmptyPathSpec = false;
          pushNonFastForward = false;
          statusHints = false;
        };
        init.defaultBranch = "dev";
        status = {
          branch = true;
          showStash = true;
          showUntrackedFiles = "all";
        };
        diff = {
          context = 3;
          renames = "copies";
          interHunkContext = 10;
        };
        pager = {
          diff = "diff-so-fancy | $PAGER";
          branch = false;
          tag = false;
        };
        "diff-so-fancy".markEmptyLines = false;
        interactive = {
          diffFilter = "diff-so-fancy --patch";
          singleKey = true;
        };
        push = {
          autoSetupRemote = true;
          default = "current";
          followTags = true;
        };
        pull = {
          default = "current";
          rebase = true;
        };
        rebase = {
          autoStash = true;
          missingCommitsCheck = "warn";
        };
        log.abbrevCommit = true;
        branch.sort = "-committerdate";
        tag = {
          sort = "-taggerdate";
          gpgsign = true;
          forceSignAnnotated = true;
        };
        commit.gpgsign = true;
        "gpg \"ssh\"" = {
          program = "ssh-keygen";
          allowedSignersFile = "~/.ssh/allowed_signers";
        };
        gpg = {
          format = "ssh";
          program = "gpg";
        };
      };
      aliases = {
        sw = "switch";
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        lg = "log --oneline --graph --decorate -20";
      };
      ignores = [
        "*.swp"
        "*.swo"
        "*~"
        ".DS_Store"
        "Thumbs.db"
        "__pycache__/"
        "*.pyc"
        ".env"
        "node_modules/"
        ".direnv/"
        "result"
      ];
    };
  };

  flake.homeManagerModules.parazeeknovaFish = { pkgs, lib, ... }: {
    programs.fish = {
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

  flake.homeManagerModules.parazeeknovaStarship = { pkgs, lib, ... }: {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        command_timeout = 1000;
        add_newline = false;
        format = "$directory\n\${custom.giturl}\n$git_branch\n$git_state\n\${custom.git_wrapper}\n\n➜ ";
        right_format = "$all\${custom.gcex}";
        palette = "matugen";

        palettes.matugen = {
          rosewater = "#f8bb71";
          flamingo = "#f8bb71";
          pink = "#f8bb71";
          mauve = "#dfc2a2";
          red = "#ffb4ab";
          maroon = "#ffb4ab";
          peach = "#f8bb71";
          yellow = "#f8bb71";
          green = "#f8bb71";
          teal = "#f8bb71";
          sky = "#dfc2a2";
          sapphire = "#f8bb71";
          blue = "#f8bb71";
          lavender = "#dfc2a2";
          text = "#eee0d4";
          subtext1 = "#d4c4b5";
          subtext0 = "#d4c4b5";
          overlay2 = "#d4c4b5";
          overlay1 = "#d4c4b5";
          overlay0 = "#504539";
          surface2 = "#504539";
          surface1 = "#504539";
          surface0 = "#251e17";
          base = "#18120c";
          mantle = "#251e17";
          crust = "#251e17";
        };

        directory = {
          style = "sapphire";
          format = "[ $path ]($style)";
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = "";
            "Music" = "󰝚 ";
            "Pictures" = "";
            "Developer" = "󰲋 ";
          };
        };

        os.disabled = true;

        custom.giturl = {
          description = "Display symbol for remote Git server and username";
          command = ''bash -c '
rem=$(git config --get remote.origin.url 2> /dev/null)
sym=""
if echo "$rem" | grep -q "github"; then sym="";
elif echo "$rem" | grep -q "gitlab"; then sym="";
elif echo "$rem" | grep -q "bitbucket"; then sym="";
elif echo "$rem" | grep -q "git"; then sym="󰊢"; fi

usr=$(awk "/user:/ {print \\$2; exit}" ~/.config/gh/hosts.yml 2>/dev/null)
if [ -z "$usr" ]; then
    usr=$(git config user.name 2>/dev/null)
fi

if [ -n "$usr" ]; then
    if [ "$usr" = "parazeeknova" ]; then
        usr="pzk"
    else
        usr=$(echo "$usr" | cut -c1-3)
    fi
    echo "$sym $usr"
else
    echo "$sym"
fi
'';
          when = "git rev-parse --is-inside-work-tree 2> /dev/null";
          format = "at $output ";
        };

        git_branch = {
          symbol = "[基](base) ";
          style = "fg:lavender bg:base";
          format = "on [$symbol$branch]($style)[基](base)";
        };

        git_status.disabled = true;

        custom.git_wrapper = {
          description = "Show git status with unstaged count";
          command = ''bash -c '
ab=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
ahead=$(echo "$ab" | cut -f1)
behind=$(echo "$ab" | cut -f2)
[ -n "$ahead" ] && [ "$ahead" -gt 0 ] && ab_str="''${ahead}"
[ -n "$behind" ] && [ "$behind" -gt 0 ] && ab_str="''${ab_str}⇣''${behind}"

c=$(git status --porcelain 2>/dev/null | grep -cE "^(.[^ ]|\\?\\?)")
s=""
[ "$c" -gt 0 ] && s="$c "

m=$(git status --porcelain 2>/dev/null | grep -q "^.M" && echo "!")
u=$(git status --porcelain 2>/dev/null | grep -q "^\\?\\?" && echo "?")

out=""
[ -n "$ab_str" ] && out="$ab_str "
if [ -n "$s" ] || [ -n "$m" ] || [ -n "$u" ]; then
    out="''${out}[$s$m$u]"
fi
echo "$out"
'';
          when = "git rev-parse --is-inside-work-tree 2> /dev/null";
          format = " [$output]($style)";
          style = "red bold";
        };

        nodejs.symbol = "";
        c.symbol = " ";
        rust.symbol = "";
        golang.symbol = "";
        php.symbol = "";
        java.symbol = " ";
        kotlin.symbol = "";
        haskell.symbol = "";
        python.symbol = "";
        docker_context.symbol = "";

        time = {
          disabled = true;
          time_format = "%R";
          style = "bg:peach";
          format = "[[  $time ](fg:mantle bg:foam)]($style)";
        };

        line_break.disabled = true;

        character = {
          disabled = false;
          success_symbol = "[𝘹](bold fg:green)";
          error_symbol = "[𝘹](bold fg:red)";
          vimcmd_symbol = "[ ](bold fg:cream)";
          vimcmd_replace_one_symbol = "[ ](bold fg:purple)";
          vimcmd_replace_symbol = "[ ](bold fg:purple)";
          vimcmd_visual_symbol = "[ ](bold fg:lavender)";
        };

        gcloud.disabled = true;

        custom.gcex = {
          command = "awk -F'=' '/^account/ {gsub(/[ \\t]+/, \\\"\\\", \\$2); print substr(\\$2, 1, 2); exit}' ~/.config/gcloud/configurations/config_$(cat ~/.config/gcloud/active_config 2>/dev/null || echo 'default') 2>/dev/null";
          when = "test -d ~/.config/gcloud";
          format = "[ $output ]($style)";
          style = "yellow";
          ignore_timeout = true;
        };

        bun = {
          symbol = " ";
          style = "peach";
          format = "[ $symbol($version) ]($style)";
        };
      };
    };
  };

  flake.homeManagerModules.parazeeknovaTmux = { pkgs, lib, ... }: {
    programs.tmux = {
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

  flake.homeManagerModules.parazeeknovaZoxide = { pkgs, lib, ... }: {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
