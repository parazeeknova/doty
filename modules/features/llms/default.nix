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

      environment.systemPackages = with pkgs; [
        ollama-cuda
        oterm
        lmstudio
        pi-coding-agent
        claude-code
        codex
        github-copilot-cli
      ];
    };
}
