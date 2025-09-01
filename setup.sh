#!/usr/bin/env bash
set -euo pipefail

# === Colors ===
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BLUE}=== Zdots Setup (Pure Modular, Smart Installer) ===${RESET}"

# === Paths ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/zsh"
FINAL_ZSHRC="$HOME/.zshrc"
BACKUP_FILE=""
STARSHIP_CONFIG="$HOME/.config/starship.toml"
STARSHIP_SOURCE="$SCRIPT_DIR/starship.toml"

# === Ensure Zsh is installed ===
if ! command -v zsh >/dev/null 2>&1; then
  echo -e "${YELLOW}Zsh not found. Installing with pacman...${RESET}"
  sudo pacman -Sy --needed --noconfirm zsh
else
  echo -e "${BLUE}Zsh is already installed.${RESET}"
fi

# === Ensure Zinit is installed ===
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  echo -e "${YELLOW}Installing Zinit...${RESET}"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
else
  echo -e "${BLUE}Zinit already installed.${RESET}"
fi

# === Backup existing .zshrc ===
if [[ -f "$FINAL_ZSHRC" && ! -L "$FINAL_ZSHRC" ]]; then
  ts="$(date +%Y%m%d%H%M)"
  BACKUP_FILE="$HOME/.zshrc.bak.$ts"
  echo -e "${YELLOW}Backing up existing .zshrc to $BACKUP_FILE${RESET}"
  mv "$FINAL_ZSHRC" "$BACKUP_FILE"
fi

# === Assemble new .zshrc ===
echo -e "${BLUE}▶ Assembling modules from: $MODULE_DIR${RESET}"
: > "$FINAL_ZSHRC"

# Use order.txt if present, else lexicographic order
declare -a modules=()
if [[ -f "$MODULE_DIR/order.txt" ]]; then
  echo -e "${BLUE}Using order.txt manifest${RESET}"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    modules+=("$MODULE_DIR/$line")
  done < "$MODULE_DIR/order.txt"
else
  echo -e "${BLUE}Using lexicographic filename order${RESET}"
  mapfile -t modules < <(find "$MODULE_DIR" -maxdepth 1 -type f -name '*.zsh' | sort)
fi

missing=0
for f in "${modules[@]}"; do
  if [[ -f "$f" ]]; then
    echo -e "${BLUE}  + $(basename "$f")${RESET}"
    cat "$f" >> "$FINAL_ZSHRC"
    echo "" >> "$FINAL_ZSHRC"
  else
    echo -e "${RED}  - Missing: $(basename "$f")${RESET}"
    missing=1
  fi
done

if (( missing )); then
  echo -e "${YELLOW}Some listed modules were missing. Review the output above.${RESET}"
fi

# === Compile once at build time ===
echo -e "${BLUE}▶ Compiling .zshrc for faster startup...${RESET}"
if command -v zsh >/dev/null 2>&1; then
  zsh -fc 'zcompile ~/.zshrc' || echo -e "${YELLOW}zcompile failed; continuing without bytecode cache.${RESET}"
else
  echo -e "${RED}Zsh not found during compile step; skipping zcompile.${RESET}"
fi

# === Merge from backup ===
if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
  echo -e "${YELLOW}A previous .zshrc backup was found: $BACKUP_FILE${RESET}"
  imported_any=false
  maybe_add_footer() {
    if [ "$imported_any" = false ]; then
      {
        echo ""
        echo "# -------------------------------------------------------------------"
        echo "# Imported from previous .zshrc backup on $(date)"
        echo "# -------------------------------------------------------------------"
      } >> "$FINAL_ZSHRC"
      imported_any=true
    fi
  }

  for section in aliases exports PATH functions; do
    case $section in
      aliases)
        read -rp "$(echo -e "${YELLOW}Merge aliases from backup? [Y/n]: ${RESET}")" REPLY
        if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
          grep -E '^alias ' "$BACKUP_FILE" | while read -r line; do
            if ! grep -Fxq "$line" "$FINAL_ZSHRC"; then
              maybe_add_footer
              echo "$line" >> "$FINAL_ZSHRC"
              echo -e "${BLUE}Imported alias:${RESET} $line"
            fi
          done
        fi
        ;;
      exports)
        read -rp "$(echo -e "${YELLOW}Merge exports from backup? [Y/n]: ${RESET}")" REPLY
        if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
          grep -E '^export ' "$BACKUP_FILE" | while read -r line; do
            if ! grep -Fxq "$line" "$FINAL_ZSHRC"; then
              maybe_add_footer
              echo "$line" >> "$FINAL_ZSHRC"
              echo -e "${BLUE}Imported export:${RESET} $line"
            fi
          done
        fi
        ;;
      PATH)
        read -rp "$(echo -e "${YELLOW}Merge PATH modifications from backup? [Y/n]: ${RESET}")" REPLY
        if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
          grep -E '^PATH=' "$BACKUP_FILE" | while read -r line; do
            if ! grep -Fxq "$line" "$FINAL_ZSHRC"; then
              maybe_add_footer
              echo "$line" >> "$FINAL_ZSHRC"
              echo -e "${BLUE}Imported PATH modification:${RESET} $line"
            fi
          done
        fi
        ;;
      functions)
        read -rp "$(echo -e "${YELLOW}Merge functions from backup? [Y/n]: ${RESET}")" REPLY
        if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
          awk '
            /^([[:space:]]*function[[:space:]]+[a-zA-Z0-9_]+\s*\(\)\s*\{|^[a-zA-Z0-9_]+\s*\(\)\s*\{)/ {infunc=1; fn=$0 ORS; next}
            infunc {fn=fn $0 ORS; if (/^\}/) {print fn; infunc=0}}
          ' "$BACKUP_FILE" | while IFS= read -r block; do
            if ! grep -Fq "$block" "$FINAL_ZSHRC"; then
              maybe_add_footer
              printf "%s\n" "$block" >> "$FINAL_ZSHRC"
              echo -e "${BLUE}Imported function:${RESET} $(echo "$block" | head -n1)"
            fi
          done
        fi
        ;;
    esac
  done
fi

# === Install Starship configuration ===
if [[ -f "$STARSHIP_SOURCE" ]]; then
  echo -e "${BLUE}▶ Setting up Starship configuration${RESET}"
  mkdir -p "$(dirname "$STARSHIP_CONFIG")"
  
  if [[ -f "$STARSHIP_CONFIG" ]]; then
    echo -e "${YELLOW}Existing starship.toml found at $STARSHIP_CONFIG${RESET}"
    read -rp "$(echo -e "${YELLOW}Replace with Zdots starship config? [y/N]: ${RESET}")" REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      ts="$(date +%Y%m%d%H%M)"
      STARSHIP_BACKUP="$STARSHIP_CONFIG.bak.$ts"
      echo -e "${YELLOW}Backing up existing config to $STARSHIP_BACKUP${RESET}"
      mv "$STARSHIP_CONFIG" "$STARSHIP_BACKUP"
      cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
      echo -e "${BLUE}Starship config installed${RESET}"
    else
      echo -e "${BLUE}Keeping existing starship config${RESET}"
    fi
  else
    cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
    echo -e "${BLUE}Starship config installed to $STARSHIP_CONFIG${RESET}"
  fi
else
  echo -e "${YELLOW}Starship.toml not found in Zdots directory, skipping${RESET}"
fi

# === Offer default shell switch ===
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo -e "${YELLOW}Change default shell to Zsh? [Y/n]${RESET}"
  read -r REPLY
  if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
    chsh -s "$(command -v zsh)"
    echo -e "${YELLOW}Default shell changed. Takes effect on next login.${RESET}"
  fi
fi

# === Optional immediate switch ===
if [ -n "${BASH_VERSION-}" ]; then
  echo -e "${YELLOW}Switch to Zsh now and load your new config? [Y/n]${RESET}"
  read -r REPLY
  if [[ "$REPLY" =~ ^[Yy]$ || -z "$REPLY" ]]; then
    echo -e "${BLUE}Switching to Zsh...${RESET}"
    exec zsh -i -c "source ~/.zshrc; exec zsh -l"
  fi
fi

echo -e "${BLUE}✅ Zdots setup complete.${RESET}"
echo -e "${YELLOW}💡 Install and configure your terminal with a Mono Nerd Font${RESET}"
echo -e "${YELLOW}   Recommended: FiraCode Nerd Font or similar from https://www.nerdfonts.com${RESET}"
echo -e "${YELLOW}   After installation, make sure to set the font in your terminal preferences or configuration.${RESET}"
