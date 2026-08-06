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
        wantedBy = [ "multi-user.target" ];
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
          # First start pulls multi-GB images into the root podman store.
          # Give it 30 min; subsequent starts are near-instant (--policy missing).
          TimeoutStartSec = 1800;
          # Transient startup races (port bind collisions between stacks,
          # slow first pull) should auto-retry rather than leave the stack down.
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
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
        wantedBy = [ "multi-user.target" ];
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
          # First start pulls multi-GB images into the root podman store.
          # Give it 30 min; subsequent starts are near-instant (--policy missing).
          TimeoutStartSec = 1800;
          # The 48888 port bind collided with a stale bind on first start
          # (transient race). Auto-retry so a one-off collision self-heals.
          Restart = "on-failure";
          RestartSec = 10;
          StartLimitIntervalSec = 0;
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
        wantedBy = [ "multi-user.target" ];
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

      # ── Camofox stack ──────────────────────────────────────────────────
      systemd.services.hermes-camofox = {
        description = "Hermes local Camofox browser server (podman-compose)";
        after = [ "network-online.target" "podman.socket" "podman.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [ podman podman-compose gnused coreutils ];
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

      # ── Resource conservation: idle stop timers ────────────────────────
      # Firecrawl is only needed when hermes crawls. Stop it after 30 min of
      # idle; start on demand by systemctl start. Hindsight (memory) should
      # stay up but is capped by compose limits.
    };
}
