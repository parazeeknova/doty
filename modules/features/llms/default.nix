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
      nixpkgs.overlays = [
        (final: prev: {
          ollama-cuda = prev.ollama-cuda.overrideAttrs (old: {
            preConfigure = ''
              export CUDAToolkit_ROOT="${final.cudaPackages.cudatoolkit}"
            ''
            + (old.preConfigure or "");
          });
        })
      ];

      environment.systemPackages = with pkgs; [
        pi-coding-agent
        codex
        claude-code
        github-copilot-cli
        lmstudio
        yt-dlp
        cudatoolkit
        pkgs.ollama-cuda
        (pkgs.llama-cpp.override {
          cudaSupport = true;
        })
        # inputs.hermes-agent.packages.${pkgs.system}.desktop
      ];

      services.ollama = {
        enable = true;
        home = "/home/parazeeknova/ollama";
        package = pkgs.ollama-cuda;
        host = "127.0.0.1";
        port = 11434;
        openFirewall = false;
        user = "ollama";
        group = "ollama";
      };

      systemd.services.ollama.serviceConfig = {
        ProtectHome = lib.mkForce false;
        PrivateUsers = lib.mkForce false;
      };

      users.users.ollama.extraGroups = [ "users" ];

      system.activationScripts.ollamaHomePerm = ''
        chmod 710 /home/parazeeknova || true
      '';

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
