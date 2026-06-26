{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaSuwayomi =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # -- Suwayomi Server (Tachiyomi for Desktop) --
      services.suwayomi-server = {
        enable = true;
        package = pkgs.suwayomi-server;
        user = "parazeeknova";
        group = "users";
        dataDir = "/home/parazeeknova";
        openFirewall = false;
        settings = {
          server = {
            ip = "127.0.0.1";
            port = 29045;
            basicAuthEnabled = false;
            basicAuthUsername = "";
            basicAuthPasswordFile = null;
            downloadAsCbz = true;
            extensionRepos = [
              "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
            ];
            localSourcePath = "/home/parazeeknova/Manga";
            systemTrayEnabled = true;
          };
        };
      };

      systemd.services.suwayomi-server.environment.JAVA_TOOL_OPTIONS = "-noverify";
    };
}
