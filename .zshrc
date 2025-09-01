# Developer .zshrc — not used by end users
# This is only for testing Zdots modules directly from the repo.
# End users should run setup.sh to generate their ~/.zshrc.

MODULE_DIR="${ZDOTDIR:-$HOME}/.zdots/zsh"

for module in "$MODULE_DIR"/*.zsh; do
    source "$module"
done
