# ---- Lazy-load NVM ----
export NVM_DIR="$HOME/.nvm"

# Even though its lazy loaded still find default and add to PATH immediately
if [ -s "$NVM_DIR/alias/default" ]; then
  DEFAULT_VERSION=$(cat "$NVM_DIR/alias/default")
  
  # Handle lts/* wildcard pattern
  if [ "${DEFAULT_VERSION}" = "lts/*" ]; then
    # Find the latest LTS version directory
    if [ -d "$NVM_DIR/versions/node" ]; then
      DEFAULT_VERSION=$(find "$NVM_DIR/versions/node" -maxdepth 1 -name "v*" -type d 2>/dev/null | \
        xargs -I {} basename {} | \
        grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | \
        sort -V | \
        tail -1)
    fi
  elif [ "${DEFAULT_VERSION#lts/}" != "${DEFAULT_VERSION}" ]; then
    # Handle specific lts/name aliases
    if [ -s "$NVM_DIR/alias/${DEFAULT_VERSION}" ]; then
      DEFAULT_VERSION=$(cat "$NVM_DIR/alias/${DEFAULT_VERSION}")
      # Handle double resolution for nested aliases
      if [ -s "$NVM_DIR/alias/${DEFAULT_VERSION}" ]; then
        DEFAULT_VERSION=$(cat "$NVM_DIR/alias/${DEFAULT_VERSION}")
      fi
    fi
  fi
  
  if [ "${DEFAULT_VERSION}" = "node" ] || [ "${DEFAULT_VERSION}" = "stable" ]; then
    VERSION_DIR=$(find "$NVM_DIR/versions/node" -maxdepth 1 -name "v*" -type d 2>/dev/null | sort -V | tail -1)
  else
    VERSION_DIR=$(find "$NVM_DIR/versions/node" -maxdepth 1 -name "${DEFAULT_VERSION}*" -type d 2>/dev/null | head -1)
    if [ -z "$VERSION_DIR" ] && [ -d "$NVM_DIR/${DEFAULT_VERSION}" ]; then
      VERSION_DIR="$NVM_DIR/${DEFAULT_VERSION}"
    fi
  fi
  
  if [ -n "$VERSION_DIR" ] && [ -d "$VERSION_DIR/bin" ]; then
    export PATH="$VERSION_DIR/bin:$PATH"
  fi
fi

nvm() { 
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}
node() { nvm; node "$@"; }
npm() { nvm; npm "$@"; }
npx() { nvm; npx "$@"; }
