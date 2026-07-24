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
        inputs.hyprland-scroll-overview.packages.${pkgs.stdenv.hostPlatform.system}.default
        hyprglass
      ];
    in
    {
      home-manager.users.parazeeknova.wayland.windowManager.hyprland.plugins = hyprPlugins;
    };
}
