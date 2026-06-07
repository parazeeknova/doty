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
    "--color=bg+:#43483e,bg:#11140f,spinner:#bccbb0,hl:#a0cfd0 " \
    "--color=fg:#e1e4d9,header:#c3c8bb,info:#bccbb0,pointer:#a9d292 " \
    "--color=marker:#a0cfd0,fg+:#e1e4d9,prompt:#a9d292,hl+:#a9d292 " \
    "--color=border:#43483e,query:#e1e4d9,label:#c3c8bb,preview-bg:#1d211a " \
    "--color=preview-fg:#e1e4d9,preview-label:#a9d292 " \
    "--color=preview-border:#43483e,preview-scrollbar:#43483e " \
    "--color=gutter:#1d211a,scrollbar:#43483e"
end
