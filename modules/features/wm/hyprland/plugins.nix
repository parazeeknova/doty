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
      scrolloverview = pkgs.stdenv.mkDerivation {
        pname = "hyprland-scroll-overview";
        version = "0.1";
        src = inputs.hyprland-scroll-overview;

        dontUseCmakeConfigure = true;

        inherit (pkgs.hyprland) buildInputs;
        nativeBuildInputs = pkgs.hyprland.nativeBuildInputs ++ [
          pkgs.hyprland
          pkgs.gcc14
          pkgs.pkg-config
          pkgs.pixman
          pkgs.libdrm
          pkgs.lua5_4
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

      hyprglass = pkgs.stdenv.mkDerivation {
        pname = "hyprglass";
        version = "0.1";
        src = inputs.hyprglass;

        dontUseCmakeConfigure = true;

        inherit (pkgs.hyprland) buildInputs;
        nativeBuildInputs = pkgs.hyprland.nativeBuildInputs ++ [
          pkgs.hyprland
          pkgs.gcc14
          pkgs.pkg-config
          pkgs.pixman
          pkgs.libdrm
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

      dynamic_cursors = pkgs.stdenv.mkDerivation {
        pname = "hypr-dynamic-cursors";
        version = "0.1";
        src = inputs.hypr-dynamic-cursors;

        # Hyprland 0.56.1 removed src/ipc (moved out to hyprwire), so drop s2 IPC call from shake.cpp
        patches = [ ./patches/hypr-dynamic-cursors-0.56.1.patch ];

        postPatch = ''
          # Hyprland 0.56.2 does not have the LOG(...) macro introduced in git master.
          # Revert to Log::logger->log(...) for compatibility.
          find src -type f \( -name "*.cpp" -o -name "*.hpp" \) -exec sed -i 's/\bLOG(/Log::logger->log(/g' {} +
        '';

        dontUseCmakeConfigure = true;

        inherit (pkgs.hyprland) buildInputs;
        nativeBuildInputs = pkgs.hyprland.nativeBuildInputs ++ [
          pkgs.hyprland
          pkgs.gcc14
          pkgs.pkg-config
          pkgs.pixman
          pkgs.libdrm
          pkgs.hyprcursor
          pkgs.hyprgraphics
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

      hyprPlugins = [
        scrolloverview
        hyprglass
        dynamic_cursors
      ];
    in
    {
      home-manager.users.parazeeknova.wayland.windowManager.hyprland.plugins = hyprPlugins;
    };
}
