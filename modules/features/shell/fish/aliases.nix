{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaFishAliases = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.fish = {
      shellAliases = {
        cp = "cp -iv";
        mkdir = "mkdir -pv";
        mv = "mv -iv";
        rm = "rm -rf";
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "....." = "cd ../../../..";
        "......" = "cd ../../../../..";
        cl = "clear";
        cfon = "warp-cli connect";
        cfoff = "warp-cli disconnect";
        doty = "cd ~/doty && make sync";
        ls = "exa --color=auto --icons";
        la = "exa -la --color=auto --icons";
        ll = "exa -alh --color=auto --icons";
        lt = "exa -a --tree --color=auto --icons";
        dir = "dir --color=auto";
        vdir = "vdir --color=auto";
        grep = "grep --color=auto";
        hw = "hwinfo --short";
        psmem = "ps auxf | sort -nr -k 4";
        psmem10 = "ps auxf | sort -nr -k 4 | head -10";
        jctl = "journalctl -p 3 -xb";
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
        "+cuts" = "nvim ~/doty/.config/fish/conf.d/aliases.fish";
        ocfig = "nvim ~/doty/.config/opencode/opencode.json";
        pewup = "sudo pacman -Syyu";
        pewrm = "sudo pacman -R";
        pewin = "sudo pacman -S";
        pewsr = "sudo pacman -Ss";
        ctl = "sudo systemctl";
        uctl = "systemctl --user";
        pew = "sudo";
        nv = "nvim";
        ai = "opencode";
        fishy = "nvim ~/doty/.config/fish/config.fish";
        ghosy = "nvim ~/doty/.config/ghostty/config";
        fasty = "fastfetch";
        tx = "tmux";
        pn = "pnpm";
        buni = "bun install";
        bunc = "bun check";
        bunct = "bun check-types";
        bunt = "bun run test";
        brr = "bun run dev";
        bct = "bun run check && bun run check-types";
        cgin = "cargo install";
        cginit = "cargo init";
        cgb = "cargo build";
        cgr = "cargo run";
        tarnow = "tar -acf ";
        untar = "tar -zxvf ";
        wget = "wget -c ";
      };
      shellAbbrs = {
        g = "git";
        ga = "git add";
        gc = "git commit";
        gco = "git checkout";
        gd = "git diff";
        gl = "git log --oneline --graph --decorate -20";
        gp = "git push";
        gs = "git status";
        t = "tmux";
        ta = "tmux attach -t";
        tn = "tmux new-session -s";
        v = "nvim";
        c = "clear";
        lg = "lazygit";
      };
    };
  };
}
