function npm --description "Lazy-load nvm, then run npm"
    functions -e node npm npx nvm
    bash -c "source '$NVM_DIR/nvm.sh' && npm $argv"
end
