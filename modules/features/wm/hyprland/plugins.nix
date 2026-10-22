{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaHyprlandPlugins =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      pluginPkgs = inputs.lennette-private.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      scrolloverview = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hyprland-scroll-overview";
        version = "0.1";
        src = inputs.hyprland-scroll-overview;
        patches = [ ./patches/scrolloverview-lua-bind.patch ];

        dontUseCmakeConfigure = true;

        inherit (pluginPkgs.hyprland) buildInputs;
        nativeBuildInputs = pluginPkgs.hyprland.nativeBuildInputs ++ [
          pluginPkgs.hyprland
          pluginPkgs.gcc16
          pluginPkgs.pkg-config
          pluginPkgs.pixman
          pluginPkgs.libdrm
          pluginPkgs.lua5_5
        ];

        enableParallelBuilding = true;

        buildPhase = ''
          runHook preBuild
          make all
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib"
          cp scrolloverview.so "$out/lib/libscrolloverview.so"
          cp scrolloverview.so "$out/lib/scrolloverview.so"
          cp scrolloverview.so "$out/lib/libhyprland-scroll-overview.so"
          runHook postInstall
        '';
      };

      hyprglass = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hyprglass";
        version = "0.1";
        src = inputs.hyprglass;

        # Upstream hyprglass replaced damageSurface hooks with a per-surface commit listener,
        # so damageSurface hook conflict with scrolloverview is resolved without patching.

        postPatch = ''
          # Ensure non-executable stack so dlopen succeeds under modern NX / security enforcement
          sed -i 's/LDFLAGS = -shared/LDFLAGS = -shared -Wl,-z,noexecstack/' Makefile
          sed -i 's/\$(CC) -shared -fPIC/\$(CC) -shared -fPIC -Wl,-z,noexecstack/' Makefile
          echo '.section .note.GNU-stack,"",@progbits' >> src/ItemHelperBlob.S
        '';

        dontUseCmakeConfigure = true;

        inherit (pluginPkgs.hyprland) buildInputs;
        nativeBuildInputs = pluginPkgs.hyprland.nativeBuildInputs ++ [
          pluginPkgs.hyprland
          pluginPkgs.gcc16
          pluginPkgs.pkg-config
          pluginPkgs.pixman
          pluginPkgs.libdrm
        ];

        enableParallelBuilding = true;

        buildPhase = ''
          runHook preBuild
          make all
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib"
          cp hyprglass.so "$out/lib/libhyprglass.so"
          cp hyprglass.so "$out/lib/hyprglass.so"
          runHook postInstall
        '';
      };

      dynamic_cursors = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hypr-dynamic-cursors";
        version = "0.1";
        src = inputs.hypr-dynamic-cursors;

        dontUseCmakeConfigure = true;

        inherit (pluginPkgs.hyprland) buildInputs;
        nativeBuildInputs = pluginPkgs.hyprland.nativeBuildInputs ++ [
          pluginPkgs.hyprland
          pluginPkgs.gcc16
          pluginPkgs.pkg-config
          pluginPkgs.pixman
          pluginPkgs.libdrm
          pluginPkgs.hyprcursor
          pluginPkgs.hyprgraphics
        ];

        enableParallelBuilding = true;

        buildPhase = ''
          runHook preBuild
          make all
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib"
          cp out/dynamic-cursors.so "$out/lib/libdynamic-cursors.so"
          cp out/dynamic-cursors.so "$out/lib/dynamic-cursors.so"
          cp out/dynamic-cursors.so "$out/lib/libhypr-dynamic-cursors.so"
          runHook postInstall
        '';
      };

      hypr_edgehover = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hypr-edgehover";
        version = "0.1";
        src = inputs.hypr-edgehover;

        nativeBuildInputs = [
          pluginPkgs.cmake
          pluginPkgs.pkg-config
          pluginPkgs.hyprland
          pluginPkgs.gcc16
        ];
        buildInputs = pluginPkgs.hyprland.buildInputs;

        enableParallelBuilding = true;
      };

      hymission = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hymission";
        version = "0.11.0-master";
        src = inputs.hymission;

        patches = [ ./patches/hymission-effective-alpha.patch ];
        cmakeFlags = [ "-DBUILD_TESTING=OFF" ];

        nativeBuildInputs = [
          pluginPkgs.cmake
          pluginPkgs.pkg-config
          pluginPkgs.hyprland
          pluginPkgs.gcc16
        ];
        buildInputs = pluginPkgs.hyprland.buildInputs ++ [
          pluginPkgs.lua5_5
          pluginPkgs.glib
          pluginPkgs.gtk4
          pluginPkgs.libadwaita
          pluginPkgs.gtk4-layer-shell
        ];

        postInstall = ''
          ln -s "$out/libexec/hymission-search-input" "$out/lib/hymission-search-input"
          mkdir -p "$out/bin"
          ln -s "$out/libexec/hymission-search-input" "$out/bin/hymission-search-input"
        '';

        enableParallelBuilding = true;
      };

      layoutmode = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hyprland-layoutmode";
        version = "0.2.1";
        src = ./layoutmode;

        nativeBuildInputs = [
          pluginPkgs.cmake
          pluginPkgs.pkg-config
          pluginPkgs.hyprland
        ];
        buildInputs = pluginPkgs.hyprland.buildInputs;

        postInstall = ''
          ln -s "$out/lib/libhyprland-layoutmode.so" "$out/lib/liblayoutmode.so"
        '';

        enableParallelBuilding = true;
      };

      hyprbars = pluginPkgs.gcc16Stdenv.mkDerivation {
        pname = "hyprbars";
        version = "git-c7216a9";
        src = "${inputs.hyprland-plugins}/hyprbars";

        patches = [ ./patches/hyprbars-only-floating.patch ];

        dontUseCmakeConfigure = true;

        inherit (pluginPkgs.hyprland) buildInputs;
        nativeBuildInputs = pluginPkgs.hyprland.nativeBuildInputs ++ [
          pluginPkgs.hyprland
          pluginPkgs.gcc16
          pluginPkgs.pkg-config
          pluginPkgs.pixman
          pluginPkgs.libdrm
          pluginPkgs.cairo
          pluginPkgs.pango
          pluginPkgs.lua5_5
        ];

        enableParallelBuilding = true;

        buildPhase = ''
          runHook preBuild
          make all
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib"
          cp hyprbars.so "$out/lib/libhyprbars.so"
          cp hyprbars.so "$out/lib/hyprbars.so"
          runHook postInstall
        '';
      };

      hyprPlugins = [
        scrolloverview
        hyprglass
        dynamic_cursors
        hypr_edgehover
        hymission
        hyprbars
        layoutmode
      ];
    in
    {
      home-manager.users.parazeeknova = {
        wayland.windowManager.hyprland.plugins = hyprPlugins;
        programs.lennettePrivateOverlay.allowedPluginPaths = map (
          plugin: "${plugin}/lib/lib${plugin.pname}.so"
        ) hyprPlugins;
      };
    };
}
