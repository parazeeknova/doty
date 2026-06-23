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
    "--color=bg+:#48454e,bg:#141318,spinner:#cac3dc,hl:#eeb8cb " \
    "--color=fg:#e6e1e9,header:#c9c4d0,info:#cac3dc,pointer:#cbbeff " \
    "--color=marker:#eeb8cb,fg+:#e6e1e9,prompt:#cbbeff,hl+:#cbbeff " \
    "--color=border:#48454e,query:#e6e1e9,label:#c9c4d0,preview-bg:#201f24 " \
    "--color=preview-fg:#e6e1e9,preview-label:#cbbeff " \
    "--color=preview-border:#48454e,preview-scrollbar:#48454e " \
    "--color=gutter:#201f24,scrollbar:#48454e"
end
