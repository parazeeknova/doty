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
        users.parazeeknova = { ... }: {

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
        };
      };
    };
}
