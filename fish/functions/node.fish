function node --description "Lazy-load nvm, then run node"
    functions -e node npm npx nvm
    env NVM_DIR="$NVM_DIR" bash -lc 'source "$NVM_DIR/nvm.sh" && exec node "$@"' -- $argv
end
