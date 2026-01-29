source /usr/share/cachyos-fish-config/cachyos-config.fish

set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# Starting Scripts
starship init fish | source
zoxide init --cmd cd fish | source
# colorscript -e zwaves

# General use aliases
alias cp="cp -iv"
alias mkdir="mkdir -pv"
alias mv="mv -iv"
alias rm="rm -rf"

# eza aliases
alias ls="exa --color=auto --icons"
alias la="exa -la --color=auto --icons"
alias ll="exa -alh --color=auto --icons"
alias lt="exa -a --tree --color=auto --icons"

# colorize grep output (good for log files)
alias grep="grep --color=auto"

# Alias's and Abbr's
alias ahh paru
alias ahhh="paru -S"
alias nah="paru -R"
alias nv nvim

# system aliases
alias pewup="sudo pacman -Syyu"
alias pewrm="sudo pacman -R"
alias pewin="sudo pacman -S"
alias pewsr="sudo pacman -Ss"
alias pew sudo
alias fasty fastfetch

# Commands
alias cl clear
alias fishy="nvim ~/doty/.config/fish/config.fish"
alias ghosy="nvim ~/doty/.config/ghostty/config"

# Development
alias pn pnpm
alias buni="bun install"
alias bunc="bun check"
alias bunct="bun check-types"

# Git Goes Brrr
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
function gl
    git log --all --graph --pretty=format:'%C(magenta)%h %C(white) %an %ar%C(auto) %D%n%s%n'
end

# Cargo
alias cgin="cargo install"
alias cginit="cargo init"
alias cgb="cargo build"
alias cgr="cargo run"

fish_add_path /home/paper/.spicetify
fish_add_path /home/paper/.bun/bin

# TMUX
alias tmu="tmux new-session -A -s monkie"
if set -q TMUX
    return
end
