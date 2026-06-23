{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishAliases =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova.programs.fish = {
        shellAliases = {
          # -- File Operations --
          cp = "cp -iv";
          mkdir = "mkdir -pv";
          mv = "mv -iv";
          rm = "rm -rf";
          v = "vim";
          c = "clear";

          # -- Navigation --
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";
          "....." = "cd ../../../..";
          "......" = "cd ../../../../..";

          # -- Warp VPN --
          cfon = "warp-cli connect";
          cfoff = "warp-cli disconnect";

          # -- File Listing (eza) --
          ls = "exa --color=auto --icons";
          la = "exa -la --color=auto --icons";
          ll = "exa -alh --color=auto --icons";
          lt = "exa -a --tree --color=auto --icons";
          dir = "dir --color=auto";
          vdir = "vdir --color=auto";

          # -- Search & Info --
          grep = "grep --color=auto";
          hw = "hwinfo --short";
          psmem = "ps auxf | sort -nr -k 4";
          psmem10 = "ps auxf | sort -nr -k 4 | head -10";
          jctl = "journalctl -p 3 -xb";

          # -- Dev Tools --
          nv = "nvim";
          ai = "opencode";
          fasty = "fastfetch";
          tx = "tmux";
          lg = "lazygit";

          # -- JS/TS (Bun/Pnpm) --
          pn = "pnpm";
          buni = "bun install";
          bunc = "bun check";
          bunct = "bun check-types";
          bunt = "bun run test";
          brr = "bun run dev";
          bct = "bun run check && bun run check-types";

          # -- Rust (Cargo) --
          cgin = "cargo install";
          cginit = "cargo init";
          cgb = "cargo build";
          cgr = "cargo run";

          # -- Docker / Podman --
          dk = "docker";
          dkps = "docker ps -a";
          dkimg = "docker images";
          dkst = "docker stop";
          dkrm = "docker rm";
          dkrmi = "docker rmi";
          dkc = "docker compose up";
          dkcd = "docker compose down";
          dkcl = "docker compose logs -f";
          dkcb = "docker compose build";
          dkcr = "docker compose restart";

          # -- Nix --
          doty = "cd ~/doty && sudo nixos-rebuild switch --flake .#apostrophe";
          dotes = "cd ~/doty && sudo nixos-rebuild test --flake .#apostrophe";
          nfu = "nix flake update";
          nfc = "nix flake check";
          nfsh = "nix flake show";
          nsh = "nix shell";
          npl = "nix profile list";
          npr = "nix profile remove";
          nps = "nix profile sync";
          ncg = "nix-collect-garbage -d";
          nso = "nix store optimise";
          nb = "nix build";
          nr = "nix run";
          ne = "nix eval";

          # -- Archives --
          tarnow = "tar -acf ";
          untar = "tar -zxvf ";
          wget = "wget -c ";
        };
        shellAbbrs = {
          # -- Git --
          g = "git";
          ga = "git add .";
          gco = "git checkout";
          gd = "git diff --output-indicator-new=' ' --output-indicator-old=' '";
          gl = "git log --oneline --graph --decorate -20";
          gp = "git push";
          gs = "git status --short";
          gap = "git add --patch";
          gcns = "git -c commit.gpgsign=false commit -m";

          # -- TMUX --
          t = "tmux";
          ta = "tmux attach -t";
          tn = "tmux new-session -s";
        };
      };
    };
}
