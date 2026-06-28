{ self, inputs, ... }: {
  perSystem =
    { pkgs, ... }:
    {
      packages.hypr-kinetic-scroll = pkgs.stdenv.mkDerivation {
        pname = "hypr-kinetic-scroll";
        version = "unstable";

        src = inputs.hypr-kinetic-scroll;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [
          pkgs.hyprland
          pkgs.aquamarine
          pkgs.hyprgraphics
          pkgs.hyprutils
          pkgs.hyprlang
          pkgs.hyprcursor
          pkgs.libGL
          pkgs.libxcb-wm
          pkgs.libxcb-errors
          pkgs.wayland-protocols
          pkgs.lua
          pkgs.pixman
          pkgs.libdrm
          pkgs.libinput
          pkgs.systemd
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.pango
          pkgs.cairo
        ];

        buildPhase = ''
          runHook preBuild
          make
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib
          cp hypr-kinetic-scroll.so $out/lib/libhypr-kinetic-scroll.so
          runHook postInstall
        '';
      };

      packages.hyprland-scroll-overview = pkgs.stdenv.mkDerivation {
        pname = "hyprland-scroll-overview";
        version = "unstable";

        src = inputs.hyprland-scroll-overview;

        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.cmake
          pkgs.gcc14
        ];
        buildInputs = [
          pkgs.hyprland
          pkgs.aquamarine
          pkgs.hyprgraphics
          pkgs.hyprutils
          pkgs.hyprlang
          pkgs.hyprcursor
          pkgs.libGL
          pkgs.libxcb-wm
          pkgs.libxcb-errors
          pkgs.wayland-protocols
          pkgs.lua5_4
          pkgs.pixman
          pkgs.libdrm
          pkgs.libinput
          pkgs.systemd
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.pango
          pkgs.cairo
          pkgs.glslang
        ];

        postInstall = ''
          mv $out/lib/libscrolloverview.so $out/lib/libhyprland-scroll-overview.so
        '';
      };
    };
}
