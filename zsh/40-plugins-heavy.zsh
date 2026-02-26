# ---- Autosuggestion config (set before plugin loads) ----
# 1. match_prev_cmd — suggest what usually follows the command you just ran
# 2. history        — fall back to most recent prefix match
# 3. completion     — fall back to zsh completions (flags, subcommands, paths)
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c6c6c"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ---- Heavy Plugins (turbo-loaded after prompt) ----
zinit ice wait'0' lucid
zinit light zsh-users/zsh-syntax-highlighting
zinit ice wait'0' lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
