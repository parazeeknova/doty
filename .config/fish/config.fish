#Janky KDE to Hypr Switch
if status is-login
    if test (tty) = /dev/tty1
        if not set -q HYPRLAND_INSTANCE_SIGNATURE
            exec start-hyprland
        end
    end
end

# Environment Variables
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx GPG_TTY (tty)
set -gx SSH_ASKPASS /usr/lib/seahorse/ssh-askpass
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"


# Man Page Formatting
set -x MANROFFOPT -c
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# 'Done' Plugin Settings
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# Global package PATH for node & bun
export PATH="/home/parazeeknova/.bun/bin:$PATH"
export DOCKER_COMPOSE_PROVIDER_WARNING=0

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
    mise activate fish | source
    # colorscript -e zwaves

    # TMUX Auto-Start (unless already inside one)
    if not set -q TMUX
        alias tmu="tmux new-session -A -s monkie"
    end

end
set -gx PATH $HOME/.npm-global/bin $PATH

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<
