unsetopt BEEP
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups \
       extended_history hist_expire_dups_first hist_find_no_dups
bindkey -v
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
export KEYTIMEOUT=1
