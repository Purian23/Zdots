function nvm --description "Run nvm via bash"
    env NVM_DIR="$NVM_DIR" bash -lc 'source "$NVM_DIR/nvm.sh" && nvm "$@"' -- $argv
end
