{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaMultimedia =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        penpot-desktop
        (blender.override { cudaSupport = true; })
        inkscape
        gimp
        krita
        darktable
        kdePackages.kdenlive
        audacity
      ];
    };
}
