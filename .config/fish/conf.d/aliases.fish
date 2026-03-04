# General Aliases
alias cp="cp -iv"
alias mkdir="mkdir -pv"
alias mv="mv -iv"
alias rm="rm -rf"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias cl=clear
alias cfon="warp-cli connect"
alias cfoff="warp-cli disconnect"
alias doty="cd ~/doty && stow ."

# File Listing (eza/ls)
alias ls="exa --color=auto --icons"
alias la="exa -la --color=auto --icons"
alias ll="exa -alh --color=auto --icons"
alias lt="exa -a --tree --color=auto --icons"
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

# Search & Info
alias grep='grep --color=auto'
alias hw='hwinfo --short'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias jctl="journalctl -p 3 -xb"

# Arch Linux / Pacman / Paru
alias ahh=paru
alias ahhh="paru -S"
alias nah="paru -R"
alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
alias mirror="sudo cachyos-rate-mirrors"
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

alias +cuts="nvim ~/doty/.config/fish/conf.d/aliases.fish"
alias ocfig="nvim ~/doty/.config/opencode/opencode.json"

# Pew Pew (Pacman shortcuts)
alias pewup="sudo pacman -Syyu"
alias pewrm="sudo pacman -R"
alias pewin="sudo pacman -S"
alias pewsr="sudo pacman -Ss"
alias pew=sudo

# Development
alias nv=nvim
alias ai=opencode
alias fishy="nvim ~/doty/.config/fish/config.fish"
alias ghosy="nvim ~/doty/.config/ghostty/config"
alias fasty=fastfetch

# TMUX
alias tx=tmux

# JS/TS (Bun/Pnpm)
alias pn=pnpm
alias buni="bun install"
alias bunc="bun check"
alias bunct="bun check-types"
alias brr="bun run dev"

# Rust (Cargo)
alias cgin="cargo install"
alias cginit="cargo init"
alias cgb="cargo build"
alias cgr="cargo run"

# Git
alias gs="git status --short"
alias gd="git diff --output-indicator-new=' ' --output-indicator-old=' '"
alias gds="git diff --staged"
alias ga="git add"
alias gap="git add --patch"
alias gc="git commit"
alias gp="git push"
alias gu="git pull"
alias gb="git branch"
alias gcl="git clone"

# Archives
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '

# Tmux Scripts
function hebycode
    set current_dir (pwd)
    set home_dir $HOME

    # Session name = folder name (sanitized)
    set raw_name (basename $current_dir)
    set session_name (string replace -ra '[^A-Za-z0-9_-]' '_' $raw_name)

    if tmux has-session -t $session_name 2>/dev/null
        tmux attach -t $session_name
        return
    end

    # Create session
    tmux new-session -d -s $session_name -n main -c $current_dir

    # ---- WINDOW 1 (project dir) ----
    set top_pane (tmux display-message -p -t $session_name "#{pane_id}")

    # Bottom 25%
    set bottom_pane (tmux split-window -v -p 25 -t $top_pane -c $current_dir -P -F "#{pane_id}")

    # Split top vertically
    set right_pane (tmux split-window -h -t $top_pane -c $current_dir -P -F "#{pane_id}")

    # Run opencode in top-left
    tmux send-keys -t $top_pane opencode C-m

    # ---- WINDOW 2 (home dir) ----
    tmux new-window -t $session_name -n second -c $home_dir

    # Capture initial pane (top)
    set home_top (tmux display-message -p -t $session_name "#{pane_id}")

    # Create bottom 50%
    set home_bottom (tmux split-window -v -p 50 -t $home_top -c $home_dir -P -F "#{pane_id}")

    # Run lazygit in top pane
    tmux send-keys -t $home_top lazygit C-m

    # Focus back to main window
    tmux select-window -t $session_name:main

    tmux attach -t $session_name
end
