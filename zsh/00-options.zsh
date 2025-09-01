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
