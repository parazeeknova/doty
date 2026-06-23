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
    "--color=bg+:#404944,bg:#0f1512,spinner:#b3ccbe,hl:#a6ccdf " \
    "--color=fg:#dee4de,header:#bfc9c2,info:#b3ccbe,pointer:#8cd5b4 " \
    "--color=marker:#a6ccdf,fg+:#dee4de,prompt:#8cd5b4,hl+:#8cd5b4 " \
    "--color=border:#404944,query:#dee4de,label:#bfc9c2,preview-bg:#1b211e " \
    "--color=preview-fg:#dee4de,preview-label:#8cd5b4 " \
    "--color=preview-border:#404944,preview-scrollbar:#404944 " \
    "--color=gutter:#1b211e,scrollbar:#404944"
end
