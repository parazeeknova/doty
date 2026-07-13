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

      # Systemd service to sync Google Drive to the local folder
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
          # Use a wrapper to check if a token is configured.
          # This prevents rebuild failures when no credentials are setup yet.
          ExecStart = pkgs.writeShellScript "rclone-gdrive-sync-wrapper" ''
            if [ ! -f /run/secrets/rclone.conf ] || ! grep -q "token =" /run/secrets/rclone.conf; then
              echo "Google Drive token is not configured in /run/secrets/rclone.conf. Skipping sync."
              exit 0
            fi
            exec ${pkgs.rclone}/bin/rclone --config /run/secrets/rclone.conf sync gdrive: /home/parazeeknova/secondary/cloud-sync/gdrive/ --fast-list --verbose
          '';
        };
      };

      # Timer to trigger the sync periodically (every hour)
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
