# Zinit bootstrap
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "${ZINIT_HOME:h}" && \
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

# Completion setup
autoload -Uz compinit
[[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]] && compinit -C || compinit

eval "$(zoxide init zsh)"
# Core plugins
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-completions
zinit wait lucid for \
    zsh-users/zsh-syntax-highlighting \
    zsh-users/zsh-autosuggestions

# NVM setup (deferred)
export NVM_DIR="$HOME/.nvm"
if ! command -v nvm &> /dev/null; then
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# Lazy-load NVM only when needed
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
}
node() { nvm; node "$@"; }
npm()  { nvm; npm "$@"; }
npx()  { nvm; npx "$@"; }

# PATH setup
typeset -U path
path=(
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
    "$NVM_DIR/versions/node/$(nvm current)/bin"
    $path
)
export PATH
