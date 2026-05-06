# ---- Shell Options ----
unsetopt BEEP
setopt appendhistory sharehistory hist_ignore_space hist_save_no_dups \
       extended_history hist_find_no_dups

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

# ---- Key Bindings ----
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;3C' forward-word         # Alt-→  accept next suggested word
bindkey '^[[3~' delete-char

# ---- PATH ----
typeset -U path
path=(
  "$HOME/go/bin"
  "$HOME/.local/bin"
  $path
  "$HOME/.cargo/bin"   # appended so system rustc/cargo (e.g. Fedora's) takes precedence
)
export PATH

# Source rustup's env only when no system-managed Rust toolchain is present.
# This keeps ~/.cargo/bin on PATH for Cargo-installed apps (eza, satty, …)
# without letting rustup shadow /usr/bin/rustc or /usr/bin/cargo.
[[ ! -x /usr/bin/rustc && -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
