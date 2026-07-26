{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaLlms =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        pi-coding-agent
        codex
        github-copilot-cli
        llama-cpp
        lmstudio
        yt-dlp
        cudatoolkit
      ];

      services.ollama = {
        enable = true;
      };

      services.open-webui = {
        enable = true;
        package = pkgs.open-webui;
        stateDir = "/var/lib/open-webui";
        port = 8181;
        host = "127.0.0.1";
        openFirewall = false;
        environment = {
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        };
      };
    };
}
