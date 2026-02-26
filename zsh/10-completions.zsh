# ---- Completion Styles ----
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ---- fzf-tab Styles ----
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'command -v eza >/dev/null && eza -1 --color=always $realpath || ls -1 $realpath'
zstyle ':fzf-tab:*' fzf-flags --no-mouse --color=fg:1,fg+:2 --bind=tab:accept
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
