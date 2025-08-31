#!/usr/bin/env bash
set -e

echo "🔧 Setting up zsh dotfiles for Arch Linux..."

# Install required packages
echo "📦 Installing packages..."
sudo pacman -S --needed - < install/arch-packages.txt

# Symlink .zshrc
echo "🔗 Linking .zshrc..."
ln -sf "$PWD/.zshrc" "$HOME/.zshrc"

# Create local override if missing
touch "$HOME/.zshrc.local"

echo "✅ Setup complete. Reload your shell with: source ~/.zshrc"