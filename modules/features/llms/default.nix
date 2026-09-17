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

      onnxruntime-bin = pkgs.python312Packages.buildPythonPackage {
        pname = "onnxruntime";
        version = "1.29.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/96/eb/e6968f5e41aac3125f2ff5708855f09cb0b70d85ed3115b625b0b58305ba/onnxruntime-1.29.0-cp312-cp312-manylinux_2_28_x86_64.whl";
          sha256 = "2b80d8c7ec2cc7438e4da3760b88c24568cba72c9ace96d668800a6c79419acb";
        };
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib
        ];
        propagatedBuildInputs = with pkgs.python312Packages; [
          numpy
          protobuf
          coloredlogs
          flatbuffers
          packaging
          sympy
        ];
        doCheck = false;
        pythonImportsCheck = [ "onnxruntime" ];
      };

      openwakeword = pkgs.python312Packages.buildPythonPackage {
        pname = "openwakeword";
        version = "0.6.0";
        src = pkgs.fetchFromGitHub {
          owner = "dscripka";
          repo = "openWakeWord";
          rev = "v0.6.0";
          hash = "sha256-QsXV9REAHdP0Y0fVZuU+Gt9+gcPMB60bc3DOMDYuaDM=";
        };
        format = "setuptools";
        postPatch = ''
          sed -i "/tflite-runtime/d" setup.py
        '';
        propagatedBuildInputs = [
          onnxruntime-bin
          pkgs.python312Packages.tqdm
          pkgs.python312Packages.scipy
          pkgs.python312Packages.scikit-learn
          pkgs.python312Packages.requests
        ];
        doCheck = false;
        pythonImportsCheck = [ "openwakeword" ];
      };

      # Wake word ("Hey Hermes"): OpenWakeWord & Sherpa providers.
      # The extraPythonPackages override on the flake package doesn't reach the
      # runtime PYTHONPATH, so we add openwakeword, sherpa-onnx, sentencepiece
      # site-packages directly via home.sessionVariables (content-addressed store paths).
      wakePythonPath = pkgs.lib.makeSearchPath pkgs.python312.sitePackages [
        openwakeword
        pkgs.python312Packages.sherpa-onnx
        pkgs.python312Packages.sentencepiece
        pkgs.python312Packages.pyyaml
      ];

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

      codex-desktop = pkgs.symlinkJoin {
        name = "codex-desktop";
        paths = [ inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        postBuild = ''
          rm $out/share/applications/codex-desktop.desktop
          substitute ${
            inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default
          }/share/applications/codex-desktop.desktop $out/share/applications/codex-desktop.desktop \
            --replace-fail "Name=ChatGPT Community" "Name=Codex Desktop"
        '';
      };
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
        portaudio
        codex-desktop
      ];

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          # agent-browser downloads its own Chrome (which breaks on NixOS -
          # missing libglib etc). Point it at the system Chrome instead.
          # PYTHONPATH adds sherpa-onnx + sentencepiece so hermes' wake word
          # (provider: sherpa) can import them at runtime.
          home.sessionVariables = {
            AGENT_BROWSER_EXECUTABLE_PATH = "google-chrome-stable";
            PYTHONPATH = wakePythonPath;
          };

          home.file.".pi/agent/models.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/models.json";

          home.file.".pi/agent/settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/settings.json";

          home.file.".pi/agent/mcp.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/mcp.json";

          home.file.".pi/agent/themes/matugen.json".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/themes/matugen.json";

          home.file.".pi/agent/extensions/minimal-header.ts".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/extensions/minimal-header.ts";

          home.file.".hermes/config.yaml".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/hermes-config.yaml";

          home.file.".hermes/SOUL.md".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/llms/hermes-SOUL.md";

          xdg.dataFile."applications/hermes.desktop" = {
            # The Hermes desktop app rewrites its own .desktop entry on every
            # launch, replacing this managed symlink with a regular file. Then
            # home-manager wants to back it up, finds a stale .bak, and fails
            # the whole switch. force=true overwrites without backing up.
            force = true;
            text = ''
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
              MimeType=x-scheme-handler/hermes;
            '';
          };

          xdg.dataFile."icons/hermes.png".source =
            "${hermes-desktop-patched}/share/hermes-desktop/dist/hermes.png";

          systemd.user.services.hermes-gateway = {
            Unit = {
              Description = "Hermes Agent Gateway - Messaging Platform Integration";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
              StartLimitIntervalSec = 0;
            };

            Service = {
              Type = "simple";
              # Must run via the `hermes` wrapper, not the raw venv python —
              # the wrapper sets HERMES_BUNDLED_PLUGINS, without which the
              # telegram/discord adapters are never discovered ("No adapter
              # available"). Use the absolute /run/current-system/sw path:
              # user systemd units have no PATH, so a bare `hermes` fails
              # with status 203/EXEC.
              ExecStart = "/run/current-system/sw/bin/hermes gateway run";
              Environment = "HERMES_HOME=%h/.hermes";
              # sherpa-onnx + sentencepiece for the wake word
              # (provider: sherpa). home.sessionVariables doesn't reach
              # systemd units, so set it here explicitly.
              EnvironmentFile = "${pkgs.writeText "hermes-gateway-pythonpath" ''
                PYTHONPATH=${wakePythonPath}
              ''}";
              WorkingDirectory = "%h/.hermes";
              Restart = "always";
              RestartSec = 5;
              RestartForceExitStatus = 75;
              RestartPreventExitStatus = 78;
              KillMode = "mixed";
              KillSignal = "SIGTERM";
              TimeoutStopSec = 60;
              StandardOutput = "journal";
              StandardError = "journal";
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

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
