{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  pickerDir = "${repo}/modules/features/wm/hyprland-preview-share-picker";
in
{

  flake.nixosModules.parazeeknovaHyprlandPreviewSharePicker = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, pkgs, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "hyprland-preview-share-picker/config.yaml".source = mkOutOfStoreSymlink "${pickerDir}/config.yaml";
        "hyprland-preview-share-picker/style.css".source = mkOutOfStoreSymlink "${pickerDir}/style.css";
        "hyprland-preview-share-picker/style.css.template".source = mkOutOfStoreSymlink "${pickerDir}/style.css.template";
      };
    };
  };
}
