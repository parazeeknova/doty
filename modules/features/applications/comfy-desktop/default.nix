{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaComfyDesktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      pname = "comfy-desktop";
      version = "1.1.3";
      buildId = "260925phvzmrjn6";

      src = pkgs.fetchurl {
        url = "https://download.todesktop.com/241130tqe9q3y/comfyui-desktop-2-${version}-build-${buildId}-x86_64.AppImage";
        sha256 = "0hw8hxckbb3b94sgl0ns8szxi2x7a2anaa5l5d8a24fqx4qg1v0k";
      };

      comfy-desktop = pkgs.appimageTools.wrapType2 {
        inherit pname version src;

        extraPkgs =
          pkgs: with pkgs; [
            libGL
            libGLU
            vulkan-loader
            vulkan-tools
            mesa
            libxkbcommon
            wayland

            cudaPackages.cudatoolkit
            cudaPackages.cuda_cudart
            cudaPackages.libcublas
            cudaPackages.cudnn

            stdenv.cc.cc.lib
            zlib
            openssl
            glib
            curl
            git
            coreutils
          ];

        extraInstallCommands = ''
          mkdir -p $out/share/applications $out/share/icons/hicolor/1024x1024/apps
          install -m 444 -D ''${src}/comfyui-desktop-2.png $out/share/icons/hicolor/1024x1024/apps/comfyui-desktop-2.png 2>/dev/null || true
          cat > $out/share/applications/comfy-desktop.desktop <<EOF
          [Desktop Entry]
          Name=Comfy Desktop
          Exec=env __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib:\$LD_LIBRARY_PATH CUDA_PATH=/run/opengl-driver comfy-desktop --no-sandbox %U
          Icon=comfyui-desktop-2
          Terminal=false
          Type=Application
          Comment=Official ComfyUI Desktop application with CUDA GPU acceleration
          Categories=AudioVideo;Graphics;3DGraphics;Science;ArtificialIntelligence;
          StartupWMClass=Comfy Desktop
          EOF
        '';
      };
    in
    {
      environment.systemPackages = [ comfy-desktop ];
    };
}
