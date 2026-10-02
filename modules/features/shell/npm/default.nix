{ self, inputs, ... }: {
  flake.nixosModules.parazeeknovaNpm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Declarative list of npm global packages
      globalPackages = [
        "@anthropic-ai/claude-code"
        "@native-sdk/cli"
        "@openai/codex"
        "freebuff"
        "kanban"
        "opencode-ai"
        "opencode-supermemory"
        "pyright"
        "supermemory"
      ];

      # Helper script to update all declared global packages to their latest versions
      npmUpdateGlobals = pkgs.writeShellScriptBin "npm-update-globals" ''
        set -euo pipefail
        export PATH="${pkgs.nodejs}/bin:$PATH"
        export NPM_CONFIG_PREFIX="$HOME/.npm-global"

        echo "Updating declarative npm global packages to latest..."
        packages=(
          ${lib.concatMapStringsSep "\n          " (p: ''"${p}@latest"'') globalPackages}
        )
        ${pkgs.nodejs}/bin/npm install -g --no-fund --no-audit "''${packages[@]}"
        echo "All declarative npm packages are up to date."
      '';
    in
    {
      environment.systemPackages = [
        npmUpdateGlobals
      ];

      home-manager.users.parazeeknova =
        { config, ... }:
        let
          npmPath = "${pkgs.nodejs}/bin/npm";
        in
        {
          home.file.".npmrc".text = ''
            prefix=''${HOME}/.npm-global
          '';

          home.activation.syncNpmGlobals = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            export PATH="${pkgs.nodejs}/bin:$PATH"
            export NPM_CONFIG_PREFIX="$HOME/.npm-global"
            mkdir -p "$HOME/.npm-global/bin" "$HOME/.npm-global/lib/node_modules"

            packages=(
              ${lib.concatMapStringsSep "\n              " (p: ''"${p}"'') globalPackages}
            )

            to_install=()
            for pkg in "''${packages[@]}"; do
              if [[ "$pkg" =~ ^(@[^/]+/[^@]+)(@.+)?$ ]]; then
                name="''${BASH_REMATCH[1]}"
              elif [[ "$pkg" =~ ^([^@]+)(@.+)?$ ]]; then
                name="''${BASH_REMATCH[1]}"
              else
                name="$pkg"
              fi

              if [ ! -d "$HOME/.npm-global/lib/node_modules/$name" ]; then
                to_install+=("$pkg")
              fi
            done

            if [ ''${#to_install[@]} -gt 0 ]; then
              $DRY_RUN_CMD echo "Installing missing declarative npm global packages: ''${to_install[*]}"
              $DRY_RUN_CMD ${npmPath} install -g --no-fund --no-audit "''${to_install[@]}" || {
                echo "Warning: Failed to install some npm global packages (network or registry issue)."
              }
            fi
          '';
        };
    };
}
