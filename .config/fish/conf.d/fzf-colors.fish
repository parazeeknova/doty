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
    "--color=bg+:#43483e,bg:#11140e,spinner:#bdcbaf,hl:#a0cfcf " \
    "--color=fg:#e1e4d9,header:#c4c8bb,info:#bdcbaf,pointer:#abd28f " \
    "--color=marker:#a0cfcf,fg+:#e1e4d9,prompt:#abd28f,hl+:#abd28f " \
    "--color=border:#43483e,query:#e1e4d9,label:#c4c8bb,preview-bg:#1d211a " \
    "--color=preview-fg:#e1e4d9,preview-label:#abd28f " \
    "--color=preview-border:#43483e,preview-scrollbar:#43483e " \
    "--color=gutter:#1d211a,scrollbar:#43483e"
end
