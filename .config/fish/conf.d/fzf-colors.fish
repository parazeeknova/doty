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
    "--color=bg+:#504539,bg:#18120c,spinner:#dfc2a2,hl:#bbcd9e " \
    "--color=fg:#eee0d4,header:#d4c4b5,info:#dfc2a2,pointer:#f8bb71 " \
    "--color=marker:#bbcd9e,fg+:#eee0d4,prompt:#f8bb71,hl+:#f8bb71 " \
    "--color=border:#504539,query:#eee0d4,label:#d4c4b5,preview-bg:#251e17 " \
    "--color=preview-fg:#eee0d4,preview-label:#f8bb71 " \
    "--color=preview-border:#504539,preview-scrollbar:#504539 " \
    "--color=gutter:#251e17,scrollbar:#504539"
end
