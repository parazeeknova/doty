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
      hermes-desktop = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop;
      hermes-cli = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Hermes Desktop is built with Electron's Window Controls Overlay on
      # plain Linux, which paints native min/max/close buttons in the
      # top-right. On Hyprland those are redundant (the WM provides its own
      # window controls), so strip the overlay: make getTitleBarOverlayOptions
      # return false on non-Windows (buttons disappear) and stop reserving the
      # 144px fallback width for them (no dead gap on the right of the
      # titlebar). The wrapper already edits the bundled main-process at
      # install time, so we patch the bundle there instead of rebuilding the
      # renderer. IS_WINDOWS<N> is esbuild's renamed constant — match it
      # tolerantly so a hermes update that renames it degrades to a no-op
      # (buttons come back) rather than a broken sed.
      hermes-desktop-patched = hermes-desktop.overrideAttrs (old: {
        installPhase = (old.installPhase or "") + ''
          bundle="$out/share/hermes-desktop/dist/electron-main.mjs"
          chmod u+w "$out/share/hermes-desktop/dist" "$bundle"
          sed -i 's/if (!\(IS_WINDOWS[0-9]*\) && IS_WSL) {/if (!\1) {/' "$bundle"
          sed -i '/function nativeOverlayWidth/,/return OVERLAY_FALLBACK_WIDTH;/{s/  if (isMac) {/  if (!isWindows) {/}' "$bundle"
        '';
      });
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
        hermes-desktop-patched
        hermes-cli
        opus
      ];

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          # agent-browser downloads its own Chrome (which breaks on NixOS -
          # missing libglib etc). Point it at the system Chrome instead.
          home.sessionVariables = {
            AGENT_BROWSER_EXECUTABLE_PATH = "google-chrome-stable";
          };

          home.file.".pi/agent/models.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/models.json";

          home.file.".hermes/config.yaml".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/hermes-config.yaml";

          home.file.".hermes/SOUL.md".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/hermes-SOUL.md";

          xdg.dataFile."applications/hermes.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Hermes Desktop
            GenericName=AI Assistant
            Comment=Hermes AI assistant desktop app
            Exec=hermes-desktop %U
            Icon=hermes
            Terminal=false
            Categories=Utility;Network;
            StartupNotify=true
          '';

          xdg.dataFile."icons/hermes.png".source =
            "${hermes-desktop-patched}/share/hermes-desktop/dist/hermes.png";

          systemd.user.services.llama-server = {
            Unit = {
              Description = "llama.cpp Server";
              After = [ "network.target" ];
            };

            Service = {
              Type = "simple";
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Models";
              ExecStart = "${llama-cpp-cuda}/bin/llama-server --models-dir %h/Models --models-max 1 --sleep-idle-seconds 300 -ngl 999 -t 8 -fa on --port 8899 -c 32768";
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
