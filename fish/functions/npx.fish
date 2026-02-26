function npx --description "Lazy-load nvm, then run npx"
    functions -e node npm npx nvm
    bash -c "source '$NVM_DIR/nvm.sh' && npx $argv"
end
