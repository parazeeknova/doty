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
    "--color=bg+:#42493f,bg:#11140f,spinner:#bbccb2,hl:#a0cfd3 " \
    "--color=fg:#e0e4da,header:#c2c8bc,info:#bbccb2,pointer:#a4d397 " \
    "--color=marker:#a0cfd3,fg+:#e0e4da,prompt:#a4d397,hl+:#a4d397 " \
    "--color=border:#42493f,query:#e0e4da,label:#c2c8bc,preview-bg:#1d211b " \
    "--color=preview-fg:#e0e4da,preview-label:#a4d397 " \
    "--color=preview-border:#42493f,preview-scrollbar:#42493f " \
    "--color=gutter:#1d211b,scrollbar:#42493f"
end
