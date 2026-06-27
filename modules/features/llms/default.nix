{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaLlms =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Enable the Ollama service
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
      };

      # Enable the Open WebUI service
      services.open-webui = {
        enable = true;
        package = pkgs.open-webui;
        stateDir = "/var/lib/open-webui";
        host = "127.0.0.1";
        port = 1101;
      };

      environment.systemPackages = with pkgs; [
        ollama-cuda
        llama-cpp
        mistral-rs
        oterm
        pi-coding-agent
        claude-code
        codex
        github-copilot-cli
        cudaPackages.nccl
        cudaPackages.cudnn
        cudaPackages.libnpp
        whisper-cpp
      ];
    };
}
