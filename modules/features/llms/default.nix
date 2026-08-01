{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaLlms =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        pi-coding-agent
        tailscale
        codex
        claude-code
        yt-dlp
        cudatoolkit
        (pkgs.llama-cpp.override {
          cudaSupport = true;
        })
      ];
    };
}
