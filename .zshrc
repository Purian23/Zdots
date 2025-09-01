# ---- Shell Options ----
unsetopt BEEP
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups \
       extended_history hist_expire_dups_first hist_find_no_dups

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=9023
SAVEHIST=9023

# ---- Key Bindings ----
bindkey -v
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
export KEYTIMEOUT=1

# ---- PATH ----
typeset -U path
path=(
  "$HOME/go/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  $path
)
export PATH

# ---- Cargo Env ----
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ---- Completion ----
autoload -Uz compinit
[[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]] && compinit -C || compinit

# ---- Completion Styles ----
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ---- fzf-tab styles ----
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'



# ---- Zinit Bootstrap ----
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "${ZINIT_HOME:h}" \
  && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

# ---- Light Plugins ----
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-completions

# ---- zoxide ----
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ---- Prompt ----
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ---- Heavy Plugins (Async) ----
zinit wait lucid for \
  zsh-users/zsh-syntax-highlighting \
  zsh-users/zsh-autosuggestions

# ---- Lazy-load NVM ----
export NVM_DIR="$HOME/.nvm"
nvm() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm "$@"; }
node() { nvm; node "$@"; }
npm()  { nvm; npm "$@"; }
npx()  { nvm; npx "$@"; }

# Note: Do NOT add "$NVM_DIR/versions/node/$(nvm current)/bin" to PATH here.
# That forces NVM evaluation at startup and defeats lazy-loading.

# ---- User Extras ----
# Place any personal aliases, functions, or experimental configs here.

