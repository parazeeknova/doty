{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishAliases = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.fish = {
      shellAliases = {
        # -- File Operations --
        cp = "cp -iv";
        mkdir = "mkdir -pv";
        mv = "mv -iv";
        rm = "rm -rf";

        # -- Navigation --
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "....." = "cd ../../../..";
        "......" = "cd ../../../../..";

        # -- Clear --
        cl = "clear";

        # -- Warp VPN --
        cfon = "warp-cli connect";
        cfoff = "warp-cli disconnect";

        # -- Dotfiles --
        doty = "cd ~/doty && make sync";

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

        # -- Arch Linux / Pacman / Paru --
        ahh = "paru";
        ahhh = "paru -S";
        nah = "paru -R";
        update = "sudo cachyos-rate-mirrors && sudo pacman -Syu";
        mirror = "sudo cachyos-rate-mirrors";
        cleanup = "sudo pacman -Rns (pacman -Qtdq)";
        fixpacman = "sudo rm /var/lib/pacman/db.lck";
        big = "expac -H M '%m\\t%n' | sort -h | nl";
        gitpkg = "pacman -Q | grep -i \"\\-git\" | wc -l";
        rip = "expac --timefmt='%Y-%m-%d %T' '%l\\t%n %v' | sort | tail -200 | nl";
        pewup = "sudo pacman -Syyu";
        pewrm = "sudo pacman -R";
        pewin = "sudo pacman -S";
        pewsr = "sudo pacman -Ss";

        # -- System / Services --
        ctl = "sudo systemctl";
        uctl = "systemctl --user";
        pew = "sudo";

        # -- Editors & Dev Tools --
        nv = "nvim";
        ai = "opencode";
        fishy = "nvim ~/doty/.config/fish/config.fish";
        ghosy = "nvim ~/doty/.config/ghostty/config";
        fasty = "fastfetch";

        # -- TMUX --
        tx = "tmux";

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

        # -- Archives --
        tarnow = "tar -acf ";
        untar = "tar -zxvf ";
        wget = "wget -c ";
      };
      shellAbbrs = {
        # -- Git --
        g = "git";
        ga = "git add";
        gc = "git commit";
        gco = "git checkout";
        gd = "git diff";
        gl = "git log --oneline --graph --decorate -20";
        gp = "git push";
        gs = "git status";

        # -- TMUX --
        t = "tmux";
        ta = "tmux attach -t";
        tn = "tmux new-session -s";

        # -- General --
        v = "nvim";
        c = "clear";
        lg = "lazygit";
      };
    };
  };
}
