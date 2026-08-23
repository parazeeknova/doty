{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaPortless =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      portless = pkgs.stdenv.mkDerivation rec {
        pname = "portless";
        version = "0.15.5";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
          sha256 = "0bix0jswg8na10vjziylmj744r86l5agkq15da1y1mlhsgwbfvzp";
        };

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          mkdir -p $out/libexec/portless $out/bin
          cp -r * $out/libexec/portless/
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/portless \
            --add-flags "$out/libexec/portless/dist/cli.js"
        '';
      };
    in
    {
      environment.systemPackages = [ portless ];

      # Portless HTTPS reverse proxy for *.localhost dev domains.
      #
      # Runs portless as a root systemd service so the HTTPS proxy binds to port 443 at boot
      # and survives reboots. The portless CA is trusted system-wide via security.pki.certificateFiles,
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
          ExecStart = "${portless}/bin/portless proxy start --foreground --port 443 --https --skip-trust";
          Restart = "on-failure";
          RestartSec = 2;
          KillSignal = "SIGTERM";
          TimeoutStopSec = 5;
        };
      };
    };
}
