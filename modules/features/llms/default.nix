{ self, inputs, ... }:

{
  flake.nixosModules.parazeeknovaLlms =
    { pkgs, ... }:

    {
      environment.systemPackages = with pkgs; [
        pi-coding-agent
        codex
        github-copilot-cli
        lmstudio
        yt-dlp
        cudatoolkit

        (llama-cpp.override {
          cudaSupport = true;
        })
        ollama-cuda
      ];

      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
      };

      services.open-webui = {
        enable = true;
        package = pkgs.open-webui;

        host = "127.0.0.1";
        port = 8181;

        environment = {
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        };
      };

      services.llama-cpp = {
        enable = true;
        package = pkgs.llama-cpp.override {
          cudaSupport = true;
        };
        host = "127.0.0.1";
        port = 8787;
        extraFlags = [
          "--flash-attn"
          "-ngl" "999"
          "-c" "4096"
          "-b" "1024"
          "-t" "8"
        ];
      };
    };
}