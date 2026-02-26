# ---- Autosuggestion Config ----
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c6c6c"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ---- Syntax Highlighting & Autosuggestions (turbo) ----
zinit ice wait'0' lucid
zinit light zsh-users/zsh-syntax-highlighting
zinit ice wait'0' lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
