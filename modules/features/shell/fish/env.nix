{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishEnv =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova.programs.fish = {
        shellInit = ''
          # -- Locale --
          set -gx LANG en_US.UTF-8
          set -gx LC_ALL en_US.UTF-8

          # -- SSH / GPG --
          set -gx GPG_TTY (tty)
          set -gx SSH_ASKPASS ${pkgs.seahorse}/libexec/seahorse/ssh-askpass
          set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

          # -- Man Pages --
          set -x MANROFFOPT -c
          set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

          # -- Notifications --
          set -U __done_min_cmd_duration 10000
          set -U __done_notification_urgency_level low

          # -- Paths --
          fish_add_path ~/.local/bin
          fish_add_path ~/.cargo/bin
          fish_add_path ~/.bun/bin
          fish_add_path /home/parazeeknova/.mimocode/bin

          # -- Wabi Theme System --
          set -Ux WABI_DOTFILES_DIR "$HOME/doty"
          set -Ux WABI_VM_SCAN_ROOT "$HOME/secondary/virtuals"
          set -Ux WABI_GITHUB_USER "parazeeknova"
          set -Ux WABI_PRESETS_DIR "$HOME/doty/wabi/presets"
        '';
      };
    };
}
