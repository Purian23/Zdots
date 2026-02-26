# ---- Zinit Bootstrap ----
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "${ZINIT_HOME:h}" \
  && git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

# ---- Plugins (turbo-loaded after prompt) ----
# Order matters: zsh-completions adds to fpath, then compinit scans it
zinit ice wait'0' lucid
zinit light zsh-users/zsh-completions
zinit ice wait'0' lucid atinit"autoload -Uz compinit && compinit -C; zicdreplay -q"
zinit light Aloxaf/fzf-tab

# ---- zoxide ----
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi
