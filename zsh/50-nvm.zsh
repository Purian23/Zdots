# ---- Lazy-load NVM ----
export NVM_DIR="$HOME/.nvm"
nvm() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm "$@"; }
node() { nvm; node "$@"; }
npm()  { nvm; npm "$@"; }
npx()  { nvm; npx "$@"; }

# Note: Do NOT add "$NVM_DIR/versions/node/$(nvm current)/bin" to PATH here.
# That forces NVM evaluation at startup and defeats lazy-loading.
