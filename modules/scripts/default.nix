{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  scriptsDir = "${repo}/modules/scripts";
in
{

  flake.nixosModules.parazeeknovaScripts =
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

          ghostty-tmux = pkgs.writeShellScriptBin "ghostty-tmux" ''
            SESSION_NAME="ghostty"

            # Check if the session already exists
            ${pkgs.tmux}/bin/tmux has-session -t $SESSION_NAME 2>/dev/null

            if [ $? -eq 0 ]; then
                # If the session exists, reattach to it
                exec ${pkgs.tmux}/bin/tmux attach-session -t $SESSION_NAME
            else
                # If the session doesn't exist, start a new one
                ${pkgs.tmux}/bin/tmux new-session -s $SESSION_NAME -d
                exec ${pkgs.tmux}/bin/tmux attach-session -t $SESSION_NAME
            fi
          '';
        in
        {
          home.packages = [ ghostty-tmux ];

          home.file = {
            "scripts/ghostty-tmux".source = mkOutOfStoreSymlink "${scriptsDir}/ghostty_tmux";
            "scripts/kbd_aura".source = mkOutOfStoreSymlink "${scriptsDir}/kbd_aura";
            "scripts/presets_lister".source = mkOutOfStoreSymlink "${scriptsDir}/presets_lister";
            "scripts/set_wallpaper".source = mkOutOfStoreSymlink "${scriptsDir}/set_wallpaper";
            "scripts/set_wallpaper_bin".source = mkOutOfStoreSymlink "${scriptsDir}/set_wallpaper_bin";
            "scripts/theme_switcher".source = mkOutOfStoreSymlink "${scriptsDir}/theme_switcher";
            "scripts/tmux-sessionizer".source = mkOutOfStoreSymlink "${scriptsDir}/tmux-sessionizer";
            "scripts/toggle_wallpaper_pause".source =
              mkOutOfStoreSymlink "${scriptsDir}/toggle_wallpaper_pause";
            "scripts/toggle_waydroid".source = mkOutOfStoreSymlink "${scriptsDir}/toggle_waydroid";

            ".local/share/applications/Waydroid.desktop".text = ''
              [Desktop Entry]
              Type=Application
              Name=Waydroid
              GenericName=Android Container
              Exec=${repo}/modules/scripts/toggle_waydroid
              Comment=Run Android apps in a containerized environment.
              Icon=waydroid
              Categories=Utility;
            '';

            ".local/share/applications/sklauncher.desktop".text = ''
              [Desktop Entry]
              Type=Application
              Name=SKLauncher
              GenericName=Minecraft Launcher
              Exec=nvidia-offload steam-run java -jar /home/parazeeknova/jars/SKlauncher-3.2.18.jar
              Comment=Minecraft Launcher with Nvidia GPU acceleration.
              Icon=minecraft
              Categories=Game;
            '';
          };
        };
    };
}
