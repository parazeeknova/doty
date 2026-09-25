{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaMultimedia =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        # -- Image Editors --
        gimp
        krita

        # -- Video Editors & Tools --
        kdePackages.kdenlive
        mediainfo
        ffmpeg-full

        # -- Audio Editing & Effects --
        audacity
        tenacity
        easyeffects
        helvum
        lsp-plugins
        calf
      ];
    };
}
