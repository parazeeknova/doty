{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaRclone =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Enable rclone package globally
      environment.systemPackages = [ pkgs.rclone ];

      # Decrypt the rclone configuration using sops
      sops.secrets.rclone-config = {
        path = "/run/secrets/rclone.conf";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0600";
      };

      # Symlink the user's config to a mutable runtime config copy
      # so that rclone can write and refresh OAuth tokens successfully.
      systemd.tmpfiles.rules = [
        "d /home/parazeeknova/.config/rclone 0700 parazeeknova users - -"
        "d /home/parazeeknova/.cache/rclone 0700 parazeeknova users - -"
        "L+ /home/parazeeknova/.config/rclone/rclone.conf - - - - /home/parazeeknova/.cache/rclone/rclone-runtime.conf"
      ];

      # -- Google Drive Sync Service --
      systemd.services.rclone-gdrive-sync = {
        description = "Sync Google Drive to /home/parazeeknova/secondary/cloud-sync/gdrive/";
        requires = [ "home-parazeeknova-secondary.mount" ];
        after = [
          "network-online.target"
          "home-parazeeknova-secondary.mount"
          "sops-nix.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "parazeeknova";
          # Use a wrapper to copy the read-only credentials to the mutable location
          # before running the sync command.
          ExecStart = pkgs.writeShellScript "rclone-gdrive-sync-wrapper" ''
            if [ ! -f /run/secrets/rclone.conf ] || ! grep -q "\[gdrive\]" /run/secrets/rclone.conf; then
              echo "Google Drive remote [gdrive] is not configured in /run/secrets/rclone.conf. Skipping sync."
              exit 0
            fi
            mkdir -p /home/parazeeknova/.cache/rclone
            cp -f /run/secrets/rclone.conf /home/parazeeknova/.cache/rclone/rclone-runtime.conf
            chmod 600 /home/parazeeknova/.cache/rclone/rclone-runtime.conf
            exec ${pkgs.rclone}/bin/rclone --config /home/parazeeknova/.cache/rclone/rclone-runtime.conf sync gdrive: /home/parazeeknova/secondary/cloud-sync/gdrive/ --fast-list --verbose
          '';
        };
      };

      # Timer for Google Drive sync (every hour)
      systemd.timers.rclone-gdrive-sync = {
        description = "Timer to periodically run Google Drive sync";
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };
    };
}
