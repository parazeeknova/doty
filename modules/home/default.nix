{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHome =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        users.parazeeknova = { config, pkgs, ... }: {
          imports = [
            inputs.sops-nix.homeManagerModules.sops
          ];

          sops = {
            defaultSopsFile = ../../secrets/secrets.yaml;
            age.keyFile = "/home/parazeeknova/.config/sops/age/keys.txt";
            secrets.openrouter-api-key = { };
            templates."claude-settings" = {
              content = ''
                {
                  "theme": "auto",
                  "env": {
                    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
                    "ANTHROPIC_AUTH_TOKEN": "${config.sops.placeholder.openrouter-api-key}",
                    "ANTHROPIC_API_KEY": "",
                    "ANTHROPIC_MODEL": "stealth/ox-alpha",
                    "ANTHROPIC_DEFAULT_OPUS_MODEL": "stealth/ox-alpha",
                    "ANTHROPIC_DEFAULT_SONNET_MODEL": "stealth/ox-alpha",
                    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "stealth/ox-alpha",
                    "ANTHROPIC_DEFAULT_FABLE_MODEL": "stealth/ox-alpha",
                    "CLAUDE_CODE_SUBAGENT_MODEL": "stealth/ox-alpha",
                    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
                    "CLAUDE_CODE_EFFORT_LEVEL": "max",
                    "OPENROUTER_API_KEY": "${config.sops.placeholder.openrouter-api-key}"
                  }
                }
              '';
              path = "${config.home.homeDirectory}/.claude/settings.json";
            };
          };

          home = {
            username = "parazeeknova";
            homeDirectory = "/home/parazeeknova";
            stateVersion = "24.11";
          };

          programs.home-manager.enable = true;

          # -- Systemd User Services --
          systemd.user.services.ssh-agent = {
            Unit = {
              Description = "SSH key agent";
            };
            Service = {
              Type = "simple";
              Environment = "SSH_AUTH_SOCK=%t/ssh-agent.socket";
              ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent.socket";
              ExecStartPost = "${pkgs.openssh}/bin/ssh-add %h/.ssh/github_signing_key";
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          systemd.user.services.battery-logger = {
            Unit = {
              Description = "Log battery discharge rate to history.json";
              After = [ "basic.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "%h/.config/quickshell/battery_popup/log_battery";
            };
          };

          systemd.user.timers.battery-logger = {
            Unit = {
              Description = "Log battery discharge rate timer";
            };
            Timer = {
              OnBootSec = "1min";
              OnUnitActiveSec = "6min";
              AccuracySec = "1s";
            };
            Install = {
              WantedBy = [ "timers.target" ];
            };
          };

          systemd.user.services.mail-notifier = {
            Unit = {
              Description = "Instant Push Mail Notification Watcher";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };
            Service = {
              Type = "simple";
              ExecStart = "%h/.local/bin/mail_notifier";
              Restart = "always";
              RestartSec = "10";
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      };
    };
}
