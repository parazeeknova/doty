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
    "--color=bg+:#4c4639,bg:#16130b,spinner:#d5c5a0,hl:#adcfad " \
    "--color=fg:#eae1d4,header:#cfc5b4,info:#d5c5a0,pointer:#e4c36c " \
    "--color=marker:#adcfad,fg+:#eae1d4,prompt:#e4c36c,hl+:#e4c36c " \
    "--color=border:#4c4639,query:#eae1d4,label:#cfc5b4,preview-bg:#231f17 " \
    "--color=preview-fg:#eae1d4,preview-label:#e4c36c " \
    "--color=preview-border:#4c4639,preview-scrollbar:#4c4639 " \
    "--color=gutter:#231f17,scrollbar:#4c4639"
end
