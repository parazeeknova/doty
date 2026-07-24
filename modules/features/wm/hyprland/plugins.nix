{ self, inputs, ... }: {
  perSystem =
    { pkgs, ... }:
    {
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
