{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaDeepseekHarness =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Custom default port for DeepSeek Harness Web UI.
      # DeepSeek Harness defaults to 3080; dev ports like 3000/3002 are usually busy.
      # Note: TCP port numbers must be in the range 1-65535 (16-bit uint).
      # Port 7654 is safe, unreserved, and close to user's preference.
      defaultPort = "7654";

      # Preload shim for Node.js 24:
      # DeepSeek Harness depends on `node-addon-require-builtin`, an N-API native addon
      # that scans raw V8 C++ struct offsets in memory to access `internal/modules/esm/loader`.
      # On Node.js 24 (the latest in nixpkgs), those struct layouts changed, causing:
      #   "node-addon-require-builtin unsupported: Unsupported/no-getter"
      # Node.js natively supports internal modules via `--expose-internals`. This shim
      # intercepts `require('node-addon-require-builtin')` and transparently falls back to
      # Node's native `require('internal/...')`, resolving the issue completely.
      preloadShim = pkgs.writeText "dsh-require-builtin-shim.cjs" ''
        const Module = require('module');
        const origRequire = Module.prototype.require;
        Module.prototype.require = function(id) {
          const res = origRequire.apply(this, arguments);
          if (typeof id === 'string' && (id === 'node-addon-require-builtin' || id.includes('node-addon-require-builtin'))) {
            if (res && res.requireBuiltin && !res.__patched) {
              const orig = res.requireBuiltin;
              const patched = function(mid) {
                try {
                  return orig(mid);
                } catch (e) {
                  return origRequire.call(this, mid);
                }
              };
              res.requireBuiltin = patched;
              if (res.default) {
                res.default.requireBuiltin = patched;
              }
              res.__patched = true;
            }
          }
          return res;
        };
      '';

      dshBin = pkgs.writeShellScriptBin "dsh" ''
        set -euo pipefail

        DSH_PORT="''${DSH_PORT:-${defaultPort}}"
        DSH_SHARE_DIR="''${DSH_SHARE_DIR:-$HOME/.local/share/dsh}"
        DSH_ENTRY="$DSH_SHARE_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"

        # Auto-bootstrap @deepseek-ai/dsh via pnpm if not yet installed
        if [ ! -f "$DSH_ENTRY" ]; then
          echo "DeepSeek Harness runtime not found. Bootstrapping in $DSH_SHARE_DIR via pnpm..."
          mkdir -p "$DSH_SHARE_DIR"
          (
            cd "$DSH_SHARE_DIR"
            if [ ! -f "package.json" ]; then
              ${pkgs.pnpm}/bin/pnpm init >/dev/null 2>&1 || true
            fi
            ${pkgs.pnpm}/bin/pnpm add --prefer-offline @deepseek-ai/dsh
          )
        fi

        # Process command-line arguments:
        # If user invokes `web` or `--profile web` without explicit `--port`, default to $DSH_PORT
        args=()
        has_web=0
        has_port=0

        for arg in "$@"; do
          if [ "$arg" = "web" ] || [ "$arg" = "--profile web" ]; then
            has_web=1
          fi
          if [ "$arg" = "--port" ]; then
            has_port=1
          fi
          args+=("$arg")
        done

        if [ "$has_web" -eq 1 ] && [ "$has_port" -eq 0 ]; then
          args+=("--port" "$DSH_PORT")
        fi

        # Execute Node with `--expose-internals` and the require-builtin shim
        exec ${pkgs.nodejs}/bin/node \
          --expose-internals \
          -r "${preloadShim}" \
          "$DSH_ENTRY" \
          "''${args[@]}"
      '';

      dshWeb = pkgs.writeShellScriptBin "dsh-web" ''
        set -euo pipefail

        if [ "$#" -eq 0 ]; then
          # If the systemd background service is running, open the authenticated URL in browser
          if systemctl --user is-active --quiet deepseek-harness 2>/dev/null; then
            echo "DeepSeek Harness background service is active on port ${defaultPort}."
            url=$(journalctl --user -u deepseek-harness -n 100 --no-pager 2>/dev/null | grep -o 'http://127.0.0.1:[0-9]*/?token=[^ ]*' | tail -n 1 || true)
            if [ -n "$url" ]; then
              echo "Opening: $url"
              ${pkgs.xdg-utils}/bin/xdg-open "$url" 2>/dev/null || true
            else
              echo "Opening: http://127.0.0.1:${defaultPort}"
              ${pkgs.xdg-utils}/bin/xdg-open "http://127.0.0.1:${defaultPort}" 2>/dev/null || true
            fi
            exit 0
          fi
        fi

        exec ${dshBin}/bin/dsh web "$@"
      '';
    in
    {
      environment.systemPackages = [
        dshBin
        dshWeb
      ];

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          # Background service: autostart DeepSeek Harness Web in the background on system start
          systemd.user.services.deepseek-harness = {
            Unit = {
              Description = "DeepSeek Harness Web Server";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };

            Service = {
              Type = "simple";
              ExecStart = "${dshBin}/bin/dsh web --no-open --port ${defaultPort}";
              Environment = [
                "PATH=${lib.makeBinPath [ pkgs.nodejs pkgs.pnpm pkgs.coreutils pkgs.bash ]}:/run/current-system/sw/bin"
                "HOME=%h"
                "DSH_PORT=${defaultPort}"
              ];
              WorkingDirectory = "%h";
              Restart = "always";
              RestartSec = 5;
              StandardOutput = "journal";
              StandardError = "journal";
              TimeoutStopSec = 30;
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          # Pre-bootstrap ~/.local/share/dsh on home-manager activation
          home.activation.bootstrapDeepseekHarness = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            DSH_SHARE_DIR="$HOME/.local/share/dsh"
            DSH_ENTRY="$DSH_SHARE_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
            if [ ! -f "$DSH_ENTRY" ]; then
              $DRY_RUN_CMD mkdir -p "$DSH_SHARE_DIR"
              (
                cd "$DSH_SHARE_DIR"
                if [ ! -f "package.json" ]; then
                  ${pkgs.pnpm}/bin/pnpm init >/dev/null 2>&1 || true
                fi
                $DRY_RUN_CMD ${pkgs.pnpm}/bin/pnpm add --prefer-offline @deepseek-ai/dsh || {
                  echo "Warning: DeepSeek Harness initial installation encountered a warning."
                }
              )
            fi
          '';

          xdg.dataFile."applications/deepseek-harness.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=DeepSeek Harness
            GenericName=AI Agent Harness
            Comment=DeepSeek Harness Web Interface
            Exec=dsh-web
            Icon=deepseek
            Terminal=false
            Categories=Utility;Development;
          '';
        };
    };
}
