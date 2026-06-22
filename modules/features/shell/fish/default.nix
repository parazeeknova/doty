{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFish = { config, pkgs, lib, ... }: {
    imports = [
      self.nixosModules.parazeeknovaFishEnv
      self.nixosModules.parazeeknovaFishAliases
      self.nixosModules.parazeeknovaFishFunctions
    ];

    programs.fish.enable = true;

    home-manager.users.parazeeknova.programs.fish = {
      enable = true;
      interactiveShellInit = ''
        starship init fish | source
        zoxide init --cmd cd fish | source

        if not set -q TMUX
            alias tmu="tmux new-session -A -s monkie"
        end
      '';
      shellInit = ''
        # Start Hyprland via uwsm on tty1 login
        if status is-login
            if test (tty) = /dev/tty1
                if not set -q HYPRLAND_INSTANCE_SIGNATURE
                    if command -v uwsm >/dev/null 2>&1
                        exec uwsm start hyprland-uwsm.desktop
                    else
                        exec Hyprland
                    end
                end
            end
        end

        if test -f ~/.fish_profile
            source ~/.fish_profile
        end
      '';
    };
  };
}
