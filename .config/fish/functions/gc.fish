function gc --description "git commit with automatic quote wrapping"
    if test (count $argv) -eq 0
        git commit
    else
        git commit -m "$argv"
    end
end
