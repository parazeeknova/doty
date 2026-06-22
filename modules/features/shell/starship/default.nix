{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaStarship = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        command_timeout = 1000;
        add_newline = false;
        format = ''
          $directory''${custom.giturl}
          $git_branch$git_state''${custom.git_wrapper}

          ➜
        '';
        right_format = "$all''${custom.gcex}";
        palette = "matugen";

        # -- Palette (wabi gruvbox) --
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

        # -- Directory --
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

        # -- OS --
        os = {
          disabled = true;
          symbols = {
            Windows = "󰍲";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
            Debian = "󰣚";
            Redhat = "󱄛";
            RedHatEnterprise = "󱄛";
          };
        };

        # -- Custom: Git URL --
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

        # -- Git Branch --
        git_branch = {
          symbol = "[基](base) ";
          style = "fg:lavender bg:base";
          format = "on [$symbol$branch]($style)[基](base)";
        };

        # -- Git Status --
        git_status.disabled = true;

        # -- Custom: Git Wrapper --
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

        # -- Language Symbols --
        nodejs = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
        };
        c = {
          symbol = " ";
          format = "[ $symbol( $version) ]($style)";
        };
        rust = {
          symbol = "";
          format = "[ $symbol $version ]($style)";
        };
        golang = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
          detect_files = [ "go.mod" ];
        };
        php = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
        };
        java = {
          symbol = " ";
          format = "[ $symbol( $version) ]($style)";
        };
        kotlin = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
        };
        haskell = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
        };
        python = {
          symbol = "";
          format = "[ $symbol( $version) ]($style)";
        };
        docker_context = {
          symbol = "";
          format = "[ $symbol( $context) ]($style)";
        };

        # -- Time --
        time = {
          disabled = true;
          time_format = "%R";
          style = "bg:peach";
          format = "[[  $time ](fg:mantle bg:foam)]($style)";
        };

        # -- Line Break --
        line_break.disabled = true;

        # -- Character --
        character = {
          disabled = false;
          success_symbol = "[𝘹](bold fg:green)";
          error_symbol = "[𝘹](bold fg:red)";
          vimcmd_symbol = "[ ](bold fg:cream)";
          vimcmd_replace_one_symbol = "[ ](bold fg:purple)";
          vimcmd_replace_symbol = "[ ](bold fg:purple)";
          vimcmd_visual_symbol = "[ ](bold fg:lavender)";
        };

        # -- Google Cloud --
        gcloud.disabled = true;

        # -- Custom: GC EX --
        custom.gcex = {
          command = "awk -F'=' '/^account/ {gsub(/[ \\t]+/, \\\"\\\", \\$2); print substr(\\$2, 1, 2); exit}' ~/.config/gcloud/configurations/config_$(cat ~/.config/gcloud/active_config 2>/dev/null || echo 'default') 2>/dev/null";
          when = "test -d ~/.config/gcloud";
          format = "[ $output ]($style)";
          style = "yellow";
          ignore_timeout = true;
        };

        # -- Bun --
        bun = {
          symbol = " ";
          style = "peach";
          format = "[ $symbol($version) ]($style)";
        };
      };
    };
  };
}
