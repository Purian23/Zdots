function npm --description "Lazy-load nvm, then run npm"
    functions -e node npm npx nvm
    env NVM_DIR="$NVM_DIR" bash -lc 'source "$NVM_DIR/nvm.sh" && exec npm "$@"' -- $argv
end
