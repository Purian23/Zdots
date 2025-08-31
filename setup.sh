#!/usr/bin/env bash
set -e

echo "🔧 Setting up dotfiles for Arch Linux..."

# ─────────────────────────────────────────────
# 🧠 Check for Zsh and offer to install it
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
# 📦 Install required packages
# ─────────────────────────────────────────────
echo "📦 Installing packages from install/arch-packages.txt..."
sudo pacman -S --needed - < install/arch-packages.txt

# ─────────────────────────────────────────────
# 🌟 Starship check
# ─────────────────────────────────────────────
if ! command -v starship &> /dev/null; then
  echo "📦 Installing Starship via pacman..."
  sudo pacman -S starship
else
  echo "✅ Starship already installed. Skipping."
fi

# ─────────────────────────────────────────────
# 🔗 Symlink .zshrc
# ─────────────────────────────────────────────
echo "🔗 Linking .zshrc to home directory..."
ln -sf "$PWD/.zshrc" "$HOME/.zshrc"

# ─────────────────────────────────────────────
# 🧼 Create local override if missing
# ─────────────────────────────────────────────
if [[ ! -f "$HOME/.zshrc.local" ]]; then
  touch "$HOME/.zshrc.local"
  echo "# Local overrides go here" > "$HOME/.zshrc.local"
  echo "📝 Created ~/.zshrc.local for machine-specific settings."
fi

echo "✅ Setup complete. Reload your shell with: source ~/.zshrc"