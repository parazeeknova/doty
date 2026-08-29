{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHermesStack =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      stackDir = "/home/parazeeknova/doty/modules/features/llms/hermes-stack";
      envFile = "/run/secrets/hermes-stack-env";
      podmanCompose = "${pkgs.podman-compose}/bin/podman-compose";
    in
    {
      # podman is already enabled via apostropheVirtualization (dockerCompat).
      # The compose stacks run as root systemd services so they autostart at
      # boot. Enable the docker-compat socket so podman-compose can reach it.
      virtualisation.podman.dockerSocket.enable = true;

      # Secrets for the stacks (GeneralCompute key, DB passwords, bull auth).
      # Rendered into a single dotenv file that the compose services read.
      sops.secrets.generalcompute-api-key = { };
      sops.secrets.hindsight-db-password = { };
      sops.secrets.firecrawl-db-password = { };
      sops.secrets.firecrawl-bull-auth-key = { };
      sops.secrets.searxng-secret = { };
      sops.templates.hermes-stack-env = {
        content = ''
          GENERALCOMPUTE_API_KEY=${config.sops.placeholder.generalcompute-api-key}
          HINDSIGHT_DB_PASSWORD=${config.sops.placeholder.hindsight-db-password}
          FIRECRAWL_DB_PASSWORD=${config.sops.placeholder.firecrawl-db-password}
          FIRECRAWL_BULL_AUTH_KEY=${config.sops.placeholder.firecrawl-bull-auth-key}
          SEARXNG_SECRET=${config.sops.placeholder.searxng-secret}
        '';
        path = envFile;
        mode = "0400";
      };

      # ── Firecrawl stack ────────────────────────────────────────────────
      systemd.services.hermes-firecrawl = {
        description = "Hermes local Firecrawl stack (podman-compose)";
        after = [
          "network-online.target"
          "podman.socket"
          "podman.service"
        ];
        wants = [ "network-online.target" ];
        unitConfig.StopWhenUnneeded = true;
        path = with pkgs; [
          podman
          podman-compose
          gnused
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${stackDir}/firecrawl";
          EnvironmentFile = envFile;
          ExecStart = "${podmanCompose} up -d --remove-orphans";
          ExecStop = "${podmanCompose} down";
          TimeoutStartSec = 1800;
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
        };
      };

      systemd.sockets.hermes-firecrawl-proxy = {
        description = "Hermes Firecrawl Socket";
        listenStreams = [ "127.0.0.1:48002" ];
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.hermes-firecrawl-proxy = {
        description = "Hermes Firecrawl Socket Proxy";
        requires = [ "hermes-firecrawl.service" ];
        after = [ "hermes-firecrawl.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10m 127.0.0.1:48003";
        };
      };

      # ── Hindsight stack ────────────────────────────────────────────────
      systemd.services.hermes-hindsight = {
        description = "Hermes local Hindsight stack (podman-compose)";
        after = [
          "network-online.target"
          "podman.socket"
          "podman.service"
        ];
        wants = [ "network-online.target" ];
        unitConfig.StopWhenUnneeded = true;
        path = with pkgs; [
          podman
          podman-compose
          gnused
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${stackDir}/hindsight";
          EnvironmentFile = envFile;
          ExecStart = "${podmanCompose} up -d --remove-orphans";
          ExecStop = "${podmanCompose} down";
          TimeoutStartSec = 1800;
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
        };
      };

      systemd.sockets.hermes-hindsight-proxy = {
        description = "Hermes Hindsight API Socket";
        listenStreams = [ "127.0.0.1:48888" ];
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.hermes-hindsight-proxy = {
        description = "Hermes Hindsight API Socket Proxy";
        requires = [ "hermes-hindsight.service" ];
        after = [ "hermes-hindsight.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10m 127.0.0.1:48889";
        };
      };

      systemd.sockets.hermes-hindsight-ui-proxy = {
        description = "Hermes Hindsight UI Socket";
        listenStreams = [ "127.0.0.1:49999" ];
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.hermes-hindsight-ui-proxy = {
        description = "Hermes Hindsight UI Socket Proxy";
        requires = [ "hermes-hindsight.service" ];
        after = [ "hermes-hindsight.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10m 127.0.0.1:49998";
        };
      };

      # ── SearXNG stack ──────────────────────────────────────────────────
      systemd.services.hermes-searxng = {
        description = "Hermes local SearXNG (podman-compose)";
        after = [
          "network-online.target"
          "podman.socket"
          "podman.service"
        ];
        wants = [ "network-online.target" ];
        unitConfig.StopWhenUnneeded = true;
        path = with pkgs; [
          podman
          podman-compose
          gnused
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${stackDir}/searxng";
          EnvironmentFile = envFile;
          ExecStart = "${podmanCompose} up -d --remove-orphans";
          ExecStop = "${podmanCompose} down";
          TimeoutStartSec = 600;
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
        };
      };

      systemd.sockets.hermes-searxng-proxy = {
        description = "Hermes SearXNG Socket";
        listenStreams = [ "127.0.0.1:48080" ];
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.hermes-searxng-proxy = {
        description = "Hermes SearXNG Socket Proxy";
        requires = [ "hermes-searxng.service" ];
        after = [ "hermes-searxng.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10m 127.0.0.1:48081";
        };
      };

      # ── Camofox stack ──────────────────────────────────────────────────
      systemd.services.hermes-camofox = {
        description = "Hermes local Camofox browser server (podman-compose)";
        after = [
          "network-online.target"
          "podman.socket"
          "podman.service"
        ];
        wants = [ "network-online.target" ];
        unitConfig.StopWhenUnneeded = true;
        path = with pkgs; [
          podman
          podman-compose
          gnused
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "${stackDir}/camofox";
          ExecStart = "${podmanCompose} up -d --remove-orphans";
          ExecStop = "${podmanCompose} down";
          TimeoutStartSec = 600;
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
        };
      };

      systemd.sockets.hermes-camofox-proxy = {
        description = "Hermes Camofox Socket";
        listenStreams = [ "127.0.0.1:49377" ];
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.hermes-camofox-proxy = {
        description = "Hermes Camofox Socket Proxy";
        requires = [ "hermes-camofox.service" ];
        after = [ "hermes-camofox.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10m 127.0.0.1:49378";
        };
      };
    };
}
