#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.zdots"

echo "🔧 Setting up zdots in $INSTALL_DIR..."

# ─────────────────────────────────────────────
# 🧠 Ensure Zsh is installed and set as default
# ─────────────────────────────────────────────
if ! command -v zsh &> /dev/null; then
  echo "⚠️ Zsh is not installed."
  read -p "Would you like to install Zsh and set it as your default shell? (y/n): " install_zsh
  if [[ "$install_zsh" =~ ^[Yy]$ ]]; then
    sudo pacman -S zsh
    chsh -s "$(which zsh)"
    echo "✅ Zsh installed and set as default shell."
  else
    echo "❌ Zsh is required for this setup. Exiting."
    exit 1
  fi
fi

# ─────────────────────────────────────────────
# 📦 Package check and summary
# ─────────────────────────────────────────────
export PATH="$HOME/.cargo/bin:$PATH"

tools=(
  bat
  eza
  fzf
  p7zip
  starship
  unrar
  unzip
  zoxide
)

installed=()
missing=()

echo "🔍 Checking required tools..."

for tool in "${tools[@]}"; do
  if command -v "$tool" &> /dev/null; then
    installed+=("$tool")
  else
    missing+=("$tool")
  fi
done

echo ""
echo "✅ Already installed: ${installed[*]:-"None"}"
echo "📦 Missing and will be installed: ${missing[*]:-"None"}"

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "🎉 All required tools are already installed. Skipping package install."
else
  echo ""
  read -p "Proceed with installing missing packages via pacman? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    for pkg in "${missing[@]}"; do
      echo "📦 Installing $pkg..."
      sudo pacman -S --noconfirm "$pkg"
    done
  else
    echo "⏭️ Skipping package installation. You may encounter issues if required tools are missing."
  fi
fi

# ─────────────────────────────────────────────
# 🗄 Backup existing .zshrc before replacing
# ─────────────────────────────────────────────
backup_file=""
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  backup_file="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
  echo "🗄 Backing up existing .zshrc to $backup_file"
  mv "$HOME/.zshrc" "$backup_file"
fi

# ─────────────────────────────────────────────
# 🔗 Symlink .zshrc to zdots version
# ─────────────────────────────────────────────
echo "🔗 Linking zdots .zshrc to home directory..."
ln -sf "$INSTALL_DIR/.zshrc" "$HOME/.zshrc"

# ─────────────────────────────────────────────
# 🧼 Create local override if missing
# ─────────────────────────────────────────────
if [[ ! -f "$INSTALL_DIR/zshrc.local" ]]; then
  touch "$INSTALL_DIR/zshrc.local"
  echo "# Local overrides go here" > "$INSTALL_DIR/zshrc.local"
  echo "📝 Created $INSTALL_DIR/zshrc.local for machine-specific settings."
fi

# ─────────────────────────────────────────────
# 🔄 Merge settings from backup into zshrc.local
# ─────────────────────────────────────────────
if [[ -n "$backup_file" && -f "$backup_file" ]]; then
  echo "🔄 Merging settings from $backup_file into zshrc.local..."

  {
    echo ""
    echo "# ─────────────────────────────────────────────"
    echo "# Imported from previous .zshrc backup on $(date)"
    echo "# ─────────────────────────────────────────────"
  } >> "$INSTALL_DIR/zshrc.local"

  # Aliases
  grep -E '^alias ' "$backup_file" | while read -r line; do
    if ! grep -Fxq "$line" "$INSTALL_DIR/zshrc.local"; then
      echo "$line" >> "$INSTALL_DIR/zshrc.local"
    fi
  done

  # All exports
  grep -E '^export ' "$backup_file" | while read -r line; do
    if ! grep -Fxq "$line" "$INSTALL_DIR/zshrc.local"; then
      echo "$line" >> "$INSTALL_DIR/zshrc.local"
    fi
  done

  # PATH modifications without export
  grep -E '^PATH=' "$backup_file" | while read -r line; do
    if ! grep -Fxq "$line" "$INSTALL_DIR/zshrc.local"; then
      echo "$line" >> "$INSTALL_DIR/zshrc.local"
    fi
  done

  # Multi-line functions
  awk '
    /^function [a-zA-Z0-9_]+\s*\(\)\s*\{/ {infunc=1; fn=""; fn=fn $0 "\n"; next}
    infunc {fn=fn $0 "\n"; if (/^\}/) {print fn; infunc=0}}
  ' "$backup_file" | while read -r block; do
    if ! grep -Fq "$block" "$INSTALL_DIR/zshrc.local"; then
      echo -e "$block" >> "$INSTALL_DIR/zshrc.local"
    fi
  done

  echo "✅ Merge complete. Review $INSTALL_DIR/zshrc.local to confirm."
fi

echo ""
echo "✅ Setup complete. Reload your shell with: source ~/.zshrc"