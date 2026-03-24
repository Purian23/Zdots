function npx --description "Lazy-load nvm, then run npx"
    functions -e node npm npx nvm
    env NVM_DIR="$NVM_DIR" bash -lc 'source "$NVM_DIR/nvm.sh" && exec npx "$@"' -- $argv
end
