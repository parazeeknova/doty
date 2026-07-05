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
          set -gx DIRENV_LOG_FORMAT ""

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

          # -- Anthropic/Claude Code Configuration --
          set -gx ANTHROPIC_BASE_URL "https://api.deepseek.com/anthropic"
          set -gx ANTHROPIC_MODEL "deepseek-v4-pro[1m]"
          set -gx ANTHROPIC_DEFAULT_OPUS_MODEL "deepseek-v4-pro[1m]"
          set -gx ANTHROPIC_DEFAULT_SONNET_MODEL "deepseek-v4-pro[1m]"
          set -gx ANTHROPIC_DEFAULT_HAIKU_MODEL "deepseek-v4-flash"
          set -gx CLAUDE_CODE_SUBAGENT_MODEL "deepseek-v4-flash"
          set -gx CLAUDE_CODE_EFFORT_LEVEL "max"

          # -- SOPS Decrypted Environment Variables --
          if test -f /run/secrets/context7-api-key
              set -gx CONTEXT7_API_KEY (cat /run/secrets/context7-api-key)
          end
          if test -f /run/secrets/modal-api-key
              set -gx MODAL_API_KEY (cat /run/secrets/modal-api-key)
          end
          if test -f /run/secrets/anthropic-auth-token
              set -gx ANTHROPIC_AUTH_TOKEN (cat /run/secrets/anthropic-auth-token)
          end
          if test -f /run/secrets/azure-api-key
              set -gx AZURE_API_KEY (cat /run/secrets/azure-api-key)
          end
        '';
      };
    };
}
