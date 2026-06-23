if status is-interactive
  set -gx FZF_DEFAULT_OPTS \
    "--height=60% " \
    "--layout=reverse " \
    "--border=rounded " \
    "--margin=5% " \
    "--prompt=❯ " \
    "--pointer=▌ " \
    "--marker=✦ " \
    "--info=inline " \
    "--scrollbar=▏▕ " \
    "--separator=─ " \
    "--ansi " \
    "--color=bg+:#3c3836,bg:#1d2021,spinner:#7daea3,hl:#d8a657 " \
    "--color=fg:#ebdbb2,header:#d5c4a1,info:#7daea3,pointer:#a9b665 " \
    "--color=marker:#d8a657,fg+:#ebdbb2,prompt:#a9b665,hl+:#a9b665 " \
    "--color=border:#3c3836,query:#ebdbb2,label:#d5c4a1,preview-bg:#282828 " \
    "--color=preview-fg:#ebdbb2,preview-label:#a9b665 " \
    "--color=preview-border:#3c3836,preview-scrollbar:#3c3836 " \
    "--color=gutter:#282828,scrollbar:#3c3836"
end
