set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx GPG_TTY (tty)

function fish_greeting
    rustmon print --hide-name
end

# SSH agent - lazy start only when needed
function __ssh_agent_start
    if not pgrep -u (id -u) ssh-agent >/dev/null
        eval (ssh-agent -c) >/dev/null
        set -Ux SSH_AGENT_PID $SSH_AGENT_PID
        set -Ux SSH_AUTH_SOCK $SSH_AUTH_SOCK
    end
end

# Auto-start ssh-agent for git/ssh commands
function ssh
    __ssh_agent_start
    command ssh $argv
end

function git
    __ssh_agent_start
    command git $argv
end

# Format man pages
set -x MANROFFOPT -c
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
    source ~/.fish_profile
end

# Append common directories for executable files to $PATH
fish_add_path ~/.local/bin ~/.cargo/bin ~/Applications/depot_tools

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ]

    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | trim-right /)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

# Starting Scripts
starship init fish | source
zoxide init --cmd cd fish | source
# colorscript -e zwaves

# General use aliases
alias cp="cp -iv"
alias mkdir="mkdir -pv"
alias mv="mv -iv"
alias rm="rm -rf"

alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias hw='hwinfo --short'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
# Get fastest mirrors
alias mirror="sudo cachyos-rate-mirrors"
# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'
# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"
# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

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
alias ai opencode

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
alias cfon="warp-cli connect"
alias cfoff="warp-cli disconnect"

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
