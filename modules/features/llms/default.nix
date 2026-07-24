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
      ];
    };
}
