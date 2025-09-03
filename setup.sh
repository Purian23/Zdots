#!/usr/bin/env bash
set -euo pipefail

# === Colors ===
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BLUE}=== Zdots Setup (Pure Modular, Smart Installer) ===${RESET}"

# === Logging (tee all output) ===
LOGFILE="${ZDOTS_LOGFILE:-$HOME/.cache/zdots-setup.log}"
mkdir -p "$(dirname "$LOGFILE")"
# Append a header with timestamp
{
  echo "---"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Starting Zdots setup"
} >> "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# === Paths ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/zsh"
FINAL_ZSHRC="$HOME/.zshrc"
BACKUP_FILE=""
STARSHIP_CONFIG="$HOME/.config/starship.toml"
STARSHIP_SOURCE="$SCRIPT_DIR/starship.toml"

# === Prompt helper ===
# ask_yes_no "prompt" default(Y|N) -> echoes 'y' or 'n'
ask_yes_no() {
  local prompt="$1" default_answer="$2" reply
  # Global overrides
  if [[ "${ZDOTS_NO:-}" == "1" ]]; then echo y | tr 'yn' 'ny'; return; fi # always 'n'
  if [[ "${ZDOTS_YES:-}" == "1" ]]; then echo y; return; fi            # always 'y'
  # Non-interactive fallback
  if [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    [[ "$default_answer" =~ ^[Yy]$ ]] && echo y || echo n
    return
  fi
  # Interactive
  read -rp "$(echo -e "$prompt")" reply
  if [[ -z "$reply" ]]; then
    [[ "$default_answer" =~ ^[Yy]$ ]] && echo y || echo n
  else
    [[ "$reply" =~ ^[Yy]$ ]] && echo y || echo n
  fi
}

# === OS Detection ===
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

OS_TYPE="$(detect_os)"

# === Package manager detection ===
install_zsh_if_missing() {
  if command -v zsh >/dev/null 2>&1; then
    echo -e "${BLUE}Zsh is already installed.${RESET}"
    return 0
  fi

  echo -e "${YELLOW}Zsh not found. Attempting to install...${RESET}"

  # Optional override
  local pm="${ZDOTS_PM:-}"
  if [[ -n "$pm" ]]; then
    case "$pm" in
      brew|homebrew) brew install zsh && return 0 ;;
      pacman) sudo pacman -Sy --needed --noconfirm zsh && return 0 ;;
      apt|apt-get) sudo apt-get update && sudo apt-get install -y zsh && return 0 ;;
      dnf) sudo dnf install -y zsh && return 0 ;;
      yum) sudo yum install -y zsh && return 0 ;;
      zypper) sudo zypper -n install zsh && return 0 ;;
    esac
    echo -e "${RED}Unknown package manager in ZDOTS_PM='$pm'. Falling back to auto-detect.${RESET}"
  fi

  # Auto-detect based on OS
  if [[ "$OS_TYPE" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install zsh || true
    else
      echo -e "${YELLOW}Homebrew not found. Installing Homebrew first...${RESET}"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
      if command -v brew >/dev/null 2>&1; then
        brew install zsh || true
      else
        echo -e "${RED}Could not install Homebrew. Please install zsh manually.${RESET}"
        return 1
      fi
    fi
  elif [[ "$OS_TYPE" == "linux" ]]; then
    if command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --needed --noconfirm zsh || true
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y zsh || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y zsh || true
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y zsh || true
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper -n install zsh || true
    else
      echo -e "${RED}Could not detect a supported package manager. Please install zsh manually.${RESET}"
      return 1
    fi
  else
    echo -e "${RED}Unsupported OS: $(uname -s). Please install zsh manually.${RESET}"
    return 1
  fi

  if command -v zsh >/dev/null 2>&1; then
    echo -e "${BLUE}Zsh installed successfully.${RESET}"
  else
    echo -e "${RED}Automated zsh installation appears to have failed. Please install manually and re-run.${RESET}"
    return 1
  fi
}

# === Ensure Zsh is installed ===
install_zsh_if_missing || true

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
  while IFS= read -r line; do
    modules+=("$line")
  done < <(find "$MODULE_DIR" -maxdepth 1 -type f -name '*.zsh' | sort)
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
  # Respect env override for merge decision
  merge_mode="${ZDOTS_MERGE:-}"
  merge_choice=""
  merge_all=0
  # Convert to lowercase using tr for compatibility
  merge_mode_lower="$(echo "$merge_mode" | tr '[:upper:]' '[:lower:]')"
  case "$merge_mode_lower" in
    0|no|none) merge_choice="n" ;;
    1|yes|interactive) merge_choice="y" ;;
    all) merge_choice="y"; merge_all=1 ;;
  esac
  if [[ -z "$merge_choice" ]]; then
    if [[ $(ask_yes_no "${YELLOW}Review and merge anything from the backup into the new config? [y/N]: ${RESET}" N) == y ]]; then
      merge_choice="y"
    else
      merge_choice="n"
    fi
  fi

  if [[ "$merge_choice" == "y" ]]; then
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

    # Offer merge-all if not already set by env
    if (( merge_all == 0 )); then
      if [[ $(ask_yes_no "${YELLOW}Merge all categories from backup automatically? [y/N]: ${RESET}" N) == y ]]; then
        merge_all=1
      fi
    fi

    for section in aliases exports PATH functions; do
      case $section in
        aliases)
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge aliases from backup? [Y/n]: ${RESET}" Y) == y ]]; then
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
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge exports from backup? [Y/n]: ${RESET}" Y) == y ]]; then
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
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge PATH modifications from backup? [Y/n]: ${RESET}" Y) == y ]]; then
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
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge functions from backup? [Y/n]: ${RESET}" Y) == y ]]; then
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
  else
    echo -e "${BLUE}Skipping all backup merge prompts per your choice.${RESET}"
  fi
fi

# === Install Starship configuration ===
if [[ -f "$STARSHIP_SOURCE" ]]; then
  echo -e "${BLUE}▶ Setting up Starship configuration${RESET}"
  mkdir -p "$(dirname "$STARSHIP_CONFIG")"
  
  if [[ -f "$STARSHIP_CONFIG" ]]; then
    echo -e "${YELLOW}Existing starship.toml found at $STARSHIP_CONFIG${RESET}"
  if [[ $(ask_yes_no "${YELLOW}Replace with Zdots starship config? [y/N]: ${RESET}" N) == y ]]; then
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
  if [[ $(ask_yes_no "${YELLOW}Install Zdots default starship config to $STARSHIP_CONFIG? [y/N]: ${RESET}" N) == y ]]; then
      cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
      echo -e "${BLUE}Starship config installed to $STARSHIP_CONFIG${RESET}"
    else
      echo -e "${BLUE}Skipping starship config installation; no config will be created${RESET}"
    fi
  fi
else
  echo -e "${YELLOW}Starship.toml not found in Zdots directory, skipping${RESET}"
fi

# === Offer default shell switch ===
if [ "$SHELL" != "$(command -v zsh)" ]; then
  if [[ $(ask_yes_no "${YELLOW}Change default shell to Zsh? [Y/n]: ${RESET}" Y) == y ]]; then
    chsh -s "$(command -v zsh)"
    echo -e "${YELLOW}Default shell changed. Takes effect on next login.${RESET}"
  fi
fi

# === Optional immediate switch ===
if [ -n "${BASH_VERSION-}" ]; then
  if [[ $(ask_yes_no "${YELLOW}Switch to Zsh now and load your new config? [Y/n]: ${RESET}" Y) == y ]]; then
    echo -e "${BLUE}Switching to Zsh...${RESET}"
    exec zsh -i -c "source ~/.zshrc; exec zsh -l"
  fi
fi

echo -e "${BLUE}✅ Zdots setup complete.${RESET}"
echo -e "${YELLOW}💡 Install and configure your terminal with a Mono Nerd Font${RESET}"
echo -e "${YELLOW}   Recommended: FiraCode Nerd Font or similar from https://www.nerdfonts.com${RESET}"
echo -e "${YELLOW}   After installation, make sure to set the font in your terminal preferences or configuration.${RESET}"
