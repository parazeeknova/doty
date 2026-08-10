{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaPortless =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      portlessBin = "/home/parazeeknova/.npm-global/bin/portless";
    in
    {
      # Portless HTTPS reverse proxy for *.localhost dev domains.
      #
      # Runs portless (installed via npm --global) as a root systemd service so
      # the HTTPS proxy binds to port 443 at boot and survives reboots. The
      # portless CA is trusted system-wide via security.pki.certificateFiles,
      # so --skip-trust avoids re-adding it to the system trust store.
      systemd.services.portless = {
        description = "Portless HTTPS proxy";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "NetworkManager-wait-online.service"
        ];
        wants = [ "network-online.target" ];
        path = with pkgs; [
          openssl
          nodejs
          coreutils
        ];
        environment = {
          # Run the proxy against the user's state dir so routes registered by
          # `portless <name> next dev` (run as parazeeknova) are shared. Without
          # this the root service uses /root/.portless, splitting routes from the
          # apps that register them.
          HOME = "/home/parazeeknova";
          PORTLESS_STATE_DIR = "/home/parazeeknova/.portless";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.nodejs}/bin/node ${portlessBin} proxy start --foreground --port 443 --https --skip-trust";
          Restart = "on-failure";
          RestartSec = 2;
          KillSignal = "SIGTERM";
          TimeoutStopSec = 5;
        };
      };
    };
}
