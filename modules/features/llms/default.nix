{ self, inputs, ... }:

{
  flake.nixosModules.parazeeknovaLlms =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        pi-coding-agent
        codex
        github-copilot-cli
        lmstudio
        yt-dlp
        cudatoolkit
        pkgs.ollama-cuda
        (pkgs.llama-cpp.override {
          cudaSupport = true;
        })
      ];

      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
      };

      services.open-webui = {
        enable = true;
        package = pkgs.open-webui;
        stateDir = "/var/lib/open-webui";
        host = "127.0.0.1";
        port = 8181;
        openFirewall = false;
        environment = {
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        };
      };
    };
}