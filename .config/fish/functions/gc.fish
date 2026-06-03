function gc --description "git commit with automatic quote wrapping and status check"
    if test (count $argv) -eq 0
        git commit
    else
        git commit -m (string join " " $argv)
    end
    echo # print blank line for spacing
    git status --short
end
