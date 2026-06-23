{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  kittyDir = "${repo}/modules/features/shell/kitty";
in
{

  flake.nixosModules.parazeeknovaKitty =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        let
          inherit (config.lib.file) mkOutOfStoreSymlink;
        in
        {

          programs.kitty = {
            enable = true;
            settings = {
              font_family = "FiraCode Nerd Font";
              font_size = 8.5;
              cursor_shape = "beam";
              cursor_trail = 1;
              window_margin_width = 2;
              confirm_os_window_close = 0;
              shell = "fish";
            };
            keybindings = {
              "ctrl+c" = "copy_or_interrupt";
              "ctrl+f" =
                "launch --location=hsplit --allow-remote-control kitty +kitten search.py @active-kitty-window-id";
              "ctrl+shift+f" =
                "launch --location=hsplit --allow-remote-control kitty +kitten search.py @active-kitty-window-id";
              "page_up" = "scroll_page_up";
              "page_down" = "scroll_page_down";
              "ctrl+plus" = "change_font_size all +1";
              "ctrl+equal" = "change_font_size all +1";
              "ctrl+kp_add" = "change_font_size all +1";
              "ctrl+minus" = "change_font_size all -1";
              "ctrl+underscore" = "change_font_size all -1";
              "ctrl+kp_subtract" = "change_font_size all -1";
              "ctrl+0" = "change_font_size all 0";
              "ctrl+kp_0" = "change_font_size all 0";
            };
            extraConfig = ''
              include current-theme.conf
            '';
          };

          xdg.configFile = {
            "kitty/current-theme.conf".source = mkOutOfStoreSymlink "${kittyDir}/current-theme.conf";
            "kitty/current-theme.conf.template".source =
              mkOutOfStoreSymlink "${kittyDir}/current-theme.conf.template";
            "kitty/search.py".source = mkOutOfStoreSymlink "${kittyDir}/search.py";
            "kitty/scroll_mark.py".source = mkOutOfStoreSymlink "${kittyDir}/scroll_mark.py";
          };
        };
    };
}
