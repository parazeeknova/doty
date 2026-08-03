{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaLlms =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      llama-cpp-cuda = pkgs.llama-cpp.override { cudaSupport = true; };
    in
    {
      environment.systemPackages = with pkgs; [
        pi-coding-agent
        tailscale
        codex
        claude-code
        yt-dlp
        cudatoolkit
        llama-cpp-cuda
      ];

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          home.file.".pi/agent/models.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/models.json";

          systemd.user.services.llama-server = {
            Unit = {
              Description = "llama.cpp Server";
              After = [ "network.target" ];
            };

            Service = {
              Type = "simple";
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Models";
              ExecStart = "${llama-cpp-cuda}/bin/llama-server --models-dir=%h/Models --models-max 1 --sleep-idle-seconds 300 -ngl 999 -t 8 -fa on --port 8899 -c 32768";
              Restart = "on-failure";
              RestartSec = 5;
              Nice = 10;
              IOSchedulingClass = "best-effort";
              IOSchedulingPriority = 7;
              StandardOutput = "journal";
              StandardError = "journal";
              KillSignal = "SIGINT";
              TimeoutStopSec = 30;
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
    };
}
