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
    "--color=bg+:#50453a,bg:#19120c,spinner:#e1c1a3,hl:#bfcc9b " \
    "--color=fg:#eee0d5,header:#d5c3b5,info:#e1c1a3,pointer:#fcb974 " \
    "--color=marker:#bfcc9b,fg+:#eee0d5,prompt:#fcb974,hl+:#fcb974 " \
    "--color=border:#50453a,query:#eee0d5,label:#d5c3b5,preview-bg:#261e18 " \
    "--color=preview-fg:#eee0d5,preview-label:#fcb974,preview-header:#d5c3b5 " \
    "--color=preview-border:#50453a,preview-scrollbar:#50453a " \
    "--color=gutter:#261e18,scrollbar:#50453a"
end
