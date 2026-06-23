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
    "--color=bg+:#50453a,bg:#18120c,spinner:#e0c1a2,hl:#bccd9d " \
    "--color=fg:#eee0d5,header:#d4c4b5,info:#e0c1a2,pointer:#f9ba72 " \
    "--color=marker:#bccd9d,fg+:#eee0d5,prompt:#f9ba72,hl+:#f9ba72 " \
    "--color=border:#50453a,query:#eee0d5,label:#d4c4b5,preview-bg:#251e17 " \
    "--color=preview-fg:#eee0d5,preview-label:#f9ba72 " \
    "--color=preview-border:#50453a,preview-scrollbar:#50453a " \
    "--color=gutter:#251e17,scrollbar:#50453a"
end
