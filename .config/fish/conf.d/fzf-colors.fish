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
    "--color=bg+:#46464f,bg:#131318,spinner:#c4c5dd,hl:#e6bad7 " \
    "--color=fg:#e4e1e9,header:#c7c5d0,info:#c4c5dd,pointer:#bcc3ff " \
    "--color=marker:#e6bad7,fg+:#e4e1e9,prompt:#bcc3ff,hl+:#bcc3ff " \
    "--color=border:#46464f,query:#e4e1e9,label:#c7c5d0,preview-bg:#1f1f25 " \
    "--color=preview-fg:#e4e1e9,preview-label:#bcc3ff " \
    "--color=preview-border:#46464f,preview-scrollbar:#46464f " \
    "--color=gutter:#1f1f25,scrollbar:#46464f"
end
