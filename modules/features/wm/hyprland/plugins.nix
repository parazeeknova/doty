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

      hyprPlugins = [
        scrolloverview
        hyprglass
      ];
    in
    {
      home-manager.users.parazeeknova.wayland.windowManager.hyprland.plugins = hyprPlugins;
    };
}
