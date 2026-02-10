# Environment Variables
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx GPG_TTY (tty)

# Man Page Formatting
set -x MANROFFOPT -c
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# 'Done' Plugin Settings
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# Path Configuration
fish_add_path ~/.local/bin 
fish_add_path ~/.cargo/bin 
fish_add_path ~/Applications/depot_tools
fish_add_path /home/paper/.spicetify
fish_add_path /home/paper/.bun/bin
fish_add_path /home/paper/.lmstudio/bin

# Source Profile (if exists)
if test -f ~/.fish_profile
    source ~/.fish_profile
end

# Interactive Session Initialization
if status is-interactive
    # Initialize Tools
    starship init fish | source
    zoxide init --cmd cd fish | source
    # colorscript -e zwaves

    # TMUX Auto-Start (unless already inside one)
    if not set -q TMUX
        alias tmu="tmux new-session -A -s monkie"
    end

    # SSH Agent Initialization
    if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c) > /dev/null
        ssh-add ~/.ssh/id_ed25519 2>/dev/null
    end
end
