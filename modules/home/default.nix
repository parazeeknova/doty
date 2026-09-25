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
          };

          home = {
            username = "parazeeknova";
            homeDirectory = "/home/parazeeknova";
            stateVersion = "24.11";
          };

          programs.home-manager.enable = true;

          # -- MangoHud Gaming Overlay Configuration --
          programs.mangohud = {
            enable = true;
            settings = {
              fps = true;
              frametime = 1;
              cpu_stats = true;
              cpu_temp = true;
              cpu_power = true;
              cpu_mhz = true;
              gpu_stats = true;
              gpu_temp = true;
              gpu_core_clock = true;
              gpu_mem_clock = true;
              gpu_power = true;
              gpu_load_change = true;
              vram = true;
              ram = true;
              battery = true;
              battery_icon = true;

              legacy_layout = false;
              horizontal = false;
              round_corners = 8;
              background_alpha = "0.5";
              background_color = "020202";
              text_color = "ffffff";
              gpu_color = "2e9762";
              cpu_color = "2e97cb";
              vram_color = "ad64c1";
              ram_color = "c26693";
              engine_color = "eb5b5b";
              frametime_color = "00ff00";

              toggle_hud = "Shift_R+F12";
              toggle_logging = "Shift_L+F2";
              upload_log = "F5";
            };
          };

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
