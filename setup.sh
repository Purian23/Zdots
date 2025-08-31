#!/usr/bin/env bash
set -e

echo "🔧 Setting up dotfiles for Arch Linux..."

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
  fzf
  zoxide
  eza
  bat
  unzip
  unrar
  p7zip
  starship
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
# 🔗 Symlink .zshrc
# ─────────────────────────────────────────────
echo ""
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

echo ""
echo "✅ Setup complete. Reload your shell with: source ~/.zshrc"
