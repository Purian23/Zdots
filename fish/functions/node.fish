function node --description "Lazy-load nvm, then run node"
    functions -e node npm npx nvm
    bash -c "source '$NVM_DIR/nvm.sh' && node $argv"
end
