# ---- Autosuggestion config (set before plugin loads) ----
# Try history first; fall back to completions (flags, subcommands, paths).
# This mirrors fish's combined history + completion + path suggestion sources.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c6c6c"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ---- Heavy Plugins (turbo-loaded after prompt) ----
zinit ice wait'0' lucid
zinit light zsh-users/zsh-syntax-highlighting
zinit ice wait'0' lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
