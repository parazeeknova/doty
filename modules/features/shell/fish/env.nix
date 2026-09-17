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
          # -- Locale & SSL Certificates --
          set -gx LANG en_US.UTF-8
          set -gx LC_ALL en_US.UTF-8
          set -gx DIRENV_LOG_FORMAT ""
          set -gx SSL_CERT_FILE "/etc/ssl/certs/ca-certificates.crt"
          set -gx SSL_CERT_DIR "/etc/ssl/certs"
          set -gx REQUESTS_CA_BUNDLE "/etc/ssl/certs/ca-certificates.crt"
          set -gx CURL_CA_BUNDLE "/etc/ssl/certs/ca-certificates.crt"

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
          fish_add_path ~/go/bin
          fish_add_path ~/.bun/bin
          fish_add_path ~/.npm-global/bin
          fish_add_path /home/parazeeknova/.cache/.bun/bin
          fish_add_path /home/parazeeknova/.mimocode/bin
          fish_add_path /home/parazeeknova/.strix/bin

          # -- Wabi Theme System --
          set -Ux WABI_DOTFILES_DIR "$HOME/doty"
          set -Ux WABI_VM_SCAN_ROOT "$HOME/secondary/virtuals"
          set -Ux WABI_GITHUB_USER "parazeeknova"
          set -Ux WABI_PRESETS_DIR "$HOME/doty/wabi/presets"

          # -- Claude Code / Merge Gateway Configuration --
          set -gx ANTHROPIC_BASE_URL "https://api-gateway.merge.dev/v1/anthropic"
          set -gx ANTHROPIC_API_KEY ""
          set -gx ANTHROPIC_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_CUSTOM_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_CUSTOM_MODEL_OPTION "zai/glm-5.3-flash"
          set -gx ANTHROPIC_CUSTOM_MODEL_OPTION_NAME "zai/glm-5.3-flash"
          set -gx CLAUDE_CODE_CUSTOM_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_DEFAULT_OPUS_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_DEFAULT_SONNET_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_DEFAULT_HAIKU_MODEL "zai/glm-5.3-flash"
          set -gx ANTHROPIC_DEFAULT_FABLE_MODEL "zai/glm-5.3-flash"
          set -gx CLAUDE_CODE_SUBAGENT_MODEL "zai/glm-5.3-flash"
          set -gx CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY "1"
          set -gx CLAUDE_CODE_EFFORT_LEVEL "max"
          set -gx CLAUDE_CODE_MAX_CONTEXT_TOKENS "1000000"
          set -gx CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT "1"

          # -- Strix Configuration --
          set -gx STRIX_LLM "openai/deepseek/deepseek-v4-flash"
          set -gx LLM_API_BASE "https://api-gateway.merge.dev/v1/openai"
          set -gx OPENAI_BASE_URL "https://api-gateway.merge.dev/v1/openai"

          # -- SOPS Decrypted Environment Variables --
          if test -f /run/secrets/openrouter-api-key
              set -gx OPENROUTER_API_KEY (cat /run/secrets/openrouter-api-key)
          end
          if test -f /run/secrets/context7-api-key
              set -gx CONTEXT7_API_KEY (cat /run/secrets/context7-api-key)
          end
          if test -f /run/secrets/mg-gateway-key-3
              set -gx MERGE_GATEWAY_API_KEY (cat /run/secrets/mg-gateway-key-3)
          else if test -f /run/secrets/merge-gateway-api-key
              set -gx MERGE_GATEWAY_API_KEY (cat /run/secrets/merge-gateway-api-key)
          end
          if test -f /run/secrets/github-token
              set -gx GITHUB_PERSONAL_ACCESS_TOKEN (cat /run/secrets/github-token)
          end
        '';
      };
    };
}
