# Custom Functions and Keybindings

# Greeting
function fish_greeting
    # rustmon print --hide-name
end

# SSH Agent - lazy start
function __ssh_agent_start
    if not pgrep -u (id -u) ssh-agent >/dev/null
        eval (ssh-agent -c) >/dev/null
        set -Ux SSH_AGENT_PID $SSH_AGENT_PID
        set -Ux SSH_AUTH_SOCK $SSH_AUTH_SOCK
    end
end

# Wrappers to auto-start ssh-agent
function ssh
    __ssh_agent_start
    command ssh $argv
end

function git
    __ssh_agent_start
    command git $argv
end

# Bang-Bang (!! and !$) Support
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

# Keybindings for Bang-Bang
if [ "$fish_key_bindings" = fish_vi_key_bindings ]
    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

# Enhanced History
function history
    builtin history --show-time='%F %T '
end

# Backup File Utility
function backup --argument filename
    cp $filename $filename.bak
end

# Enhanced Copy
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

# Git Log Graph
function gl
    git log --all --graph --pretty=format:'%C(magenta)%h %C(white) %an %ar%C(auto) %D%n%s%n'
end
