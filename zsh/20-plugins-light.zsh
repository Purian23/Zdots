# ---- Zinit Bootstrap ----
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "${ZINIT_HOME:h}" \
  && git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

# ---- Light Plugins ----
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-completions

# ---- zoxide ----
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi
