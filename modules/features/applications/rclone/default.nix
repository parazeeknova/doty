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

      # Symlink the decrypted configuration to the user's home directory
      # so that running 'rclone' manually works out-of-the-box.
      systemd.tmpfiles.rules = [
        "d /home/parazeeknova/.config/rclone 0700 parazeeknova users - -"
        "L+ /home/parazeeknova/.config/rclone/rclone.conf - - - - /run/secrets/rclone.conf"
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
          # Check if the [gdrive] remote is configured in rclone.conf
          ExecStart = pkgs.writeShellScript "rclone-gdrive-sync-wrapper" ''
            if [ ! -f /run/secrets/rclone.conf ] || ! grep -q "\[gdrive\]" /run/secrets/rclone.conf; then
              echo "Google Drive remote [gdrive] is not configured in /run/secrets/rclone.conf. Skipping sync."
              exit 0
            fi
            exec ${pkgs.rclone}/bin/rclone --config /run/secrets/rclone.conf sync gdrive: /home/parazeeknova/secondary/cloud-sync/gdrive/ --fast-list --verbose
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

      # -- Google Photos Sync Service --
      systemd.services.rclone-gphotos-sync = {
        description = "Sync Google Photos to /home/parazeeknova/secondary/cloud-sync/gphotos/";
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
          # Check if the [gphotos] remote is configured in rclone.conf
          # Syncs gphotos:media/by-month to organize photos into year/month folders locally.
          ExecStart = pkgs.writeShellScript "rclone-gphotos-sync-wrapper" ''
            if [ ! -f /run/secrets/rclone.conf ] || ! grep -q "\[gphotos\]" /run/secrets/rclone.conf; then
              echo "Google Photos remote [gphotos] is not configured in /run/secrets/rclone.conf. Skipping sync."
              exit 0
            fi
            exec ${pkgs.rclone}/bin/rclone --config /run/secrets/rclone.conf sync gphotos:media/by-month /home/parazeeknova/secondary/cloud-sync/gphotos/ --fast-list --verbose
          '';
        };
      };

      # Timer for Google Photos sync (every 2 hours)
      systemd.timers.rclone-gphotos-sync = {
        description = "Timer to periodically run Google Photos sync";
        timerConfig = {
          OnBootSec = "10m";
          OnUnitActiveSec = "2h";
        };
        wantedBy = [ "timers.target" ];
      };
    };
}
