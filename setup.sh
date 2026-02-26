#!/usr/bin/env bash
set -euo pipefail

# === Flags ===
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# === Colors ===
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

if $DRY_RUN; then
  echo -e "${YELLOW}=== Zdots Setup (DRY RUN — no changes will be made) ===${RESET}"
else
  echo -e "${BLUE}=== Zdots Setup (Pure Modular, Smart Installer) ===${RESET}"
fi

# === Logging (tee all output) ===
LOGFILE="${ZDOTS_LOGFILE:-$HOME/.cache/zdots-setup.log}"
mkdir -p "$(dirname "$LOGFILE")"
{
  echo "---"
  if $DRY_RUN; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting Zdots setup (dry run)"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting Zdots setup"
  fi
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

# === Distribution Detection ===
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    echo "${ID:-unknown}"
  elif [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  else
    echo "unknown"
  fi
}

OS_TYPE="$(detect_os)"
DISTRO="$(detect_distro)"

# Show system info
if [[ "$OS_TYPE" == "linux" ]]; then
  echo -e "${BLUE}Detected: $DISTRO Linux${RESET}"
  if [[ "$DISTRO" == "fedora" && -f /etc/fedora-release ]]; then
    FEDORA_VERSION=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
    echo -e "${BLUE}Fedora version: $FEDORA_VERSION${RESET}"
  fi
fi

# === Check for sudo/root availability (skip on macOS with Homebrew) ===
check_sudo() {
  if [[ "$OS_TYPE" == "macos" ]]; then
    return 0
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo -e "${RED}sudo is required for package installation but not found.${RESET}"
    echo -e "${YELLOW}Please install sudo or run this script as root.${RESET}"
    return 1
  fi
  return 0
}

# Run a command with sudo unless already root
maybe_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# === Package manager detection ===
install_zsh_if_missing() {
  if command -v zsh >/dev/null 2>&1; then
    echo -e "${BLUE}Zsh is already installed.${RESET}"
    return 0
  fi

  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would attempt to install zsh${RESET}"
    return 0
  fi

  echo -e "${YELLOW}Zsh not found. Attempting to install...${RESET}"

  # Check sudo availability for Linux systems
  if [[ "$OS_TYPE" == "linux" ]] && ! check_sudo; then
    return 1
  fi

  # Optional override
  local pm="${ZDOTS_PM:-}"
  if [[ -n "$pm" ]]; then
    case "$pm" in
      brew|homebrew) brew install zsh && return 0 ;;
      pacman) maybe_sudo pacman -S --needed --noconfirm zsh && return 0 ;;
      apt|apt-get) maybe_sudo apt-get update && maybe_sudo apt-get install -y zsh && return 0 ;;
      dnf) maybe_sudo dnf install -y zsh && return 0 ;;
      yum) maybe_sudo yum install -y zsh && return 0 ;;
      zypper) maybe_sudo zypper -n install zsh && return 0 ;;
      apk) maybe_sudo apk add zsh && return 0 ;;
      nix|nix-env) nix-env -iA nixpkgs.zsh && return 0 ;;
      xbps) maybe_sudo xbps-install -y zsh && return 0 ;;
      emerge|portage) maybe_sudo emerge --ask=n app-shells/zsh && return 0 ;;
    esac
    echo -e "${RED}Unknown package manager in ZDOTS_PM='$pm'. Falling back to auto-detect.${RESET}"
  fi

  # Auto-detect based on OS and available package managers
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
    # Try package managers in order of preference/commonality
    if command -v pacman >/dev/null 2>&1; then
      echo -e "${BLUE}Detected Pacman (Arch-based)${RESET}"
      maybe_sudo pacman -S --needed --noconfirm zsh || true
    elif command -v apt-get >/dev/null 2>&1; then
      echo -e "${BLUE}Detected APT (Debian-based)${RESET}"
      { maybe_sudo apt-get update && maybe_sudo apt-get install -y zsh; } || true
    elif command -v dnf >/dev/null 2>&1; then
      echo -e "${BLUE}Detected DNF (Fedora/RHEL)${RESET}"
      maybe_sudo dnf install -y zsh || true
    elif command -v zypper >/dev/null 2>&1; then
      echo -e "${BLUE}Detected Zypper (openSUSE)${RESET}"
      maybe_sudo zypper -n install zsh || true
    elif command -v yum >/dev/null 2>&1; then
      echo -e "${BLUE}Detected YUM (CentOS/RHEL)${RESET}"
      maybe_sudo yum install -y zsh || true
    elif command -v apk >/dev/null 2>&1; then
      echo -e "${BLUE}Detected APK (Alpine)${RESET}"
      maybe_sudo apk add zsh || true
    elif command -v nix-env >/dev/null 2>&1; then
      echo -e "${BLUE}Detected Nix${RESET}"
      nix-env -iA nixpkgs.zsh || true
    elif command -v xbps-install >/dev/null 2>&1; then
      echo -e "${BLUE}Detected XBPS (Void Linux)${RESET}"
      maybe_sudo xbps-install -y zsh || true
    elif command -v emerge >/dev/null 2>&1; then
      echo -e "${BLUE}Detected Portage (Gentoo)${RESET}"
      maybe_sudo emerge --ask=n app-shells/zsh || true
    else
      echo -e "${RED}Could not detect a supported package manager.${RESET}"
      echo -e "${YELLOW}Supported: pacman, apt-get, dnf, zypper, yum, apk, nix-env, xbps-install, emerge${RESET}"
      echo -e "${YELLOW}Please install zsh manually and re-run this script.${RESET}"
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
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would clone Zinit to $ZINIT_HOME${RESET}"
  else
    echo -e "${YELLOW}Installing Zinit...${RESET}"
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi
else
  echo -e "${BLUE}Zinit already installed.${RESET}"
fi

# === Backup existing .zshrc ===
if [[ -f "$FINAL_ZSHRC" && ! -L "$FINAL_ZSHRC" ]]; then
  ts="$(date +%Y%m%d%H%M)"
  BACKUP_FILE="$HOME/.zshrc.bak.$ts"
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would back up $FINAL_ZSHRC to $BACKUP_FILE${RESET}"
  else
    echo -e "${YELLOW}Backing up existing .zshrc to $BACKUP_FILE${RESET}"
    mv "$FINAL_ZSHRC" "$BACKUP_FILE"
  fi
fi

# === Assemble new .zshrc ===
echo -e "${BLUE}▶ Assembling modules from: $MODULE_DIR${RESET}"

# Use order.txt if present, else lexicographic glob order
declare -a modules=()
if [[ -f "$MODULE_DIR/order.txt" ]]; then
  echo -e "${BLUE}Using order.txt manifest${RESET}"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    modules+=("$MODULE_DIR/$line")
  done < "$MODULE_DIR/order.txt"
else
  echo -e "${BLUE}Using lexicographic filename order${RESET}"
  for f in "$MODULE_DIR"/*.zsh; do
    [[ -f "$f" ]] && modules+=("$f")
  done
fi

if $DRY_RUN; then
  for f in "${modules[@]}"; do
    if [[ -f "$f" ]]; then
      echo -e "${BLUE}  [DRY RUN] Would include $(basename "$f")${RESET}"
    else
      echo -e "${RED}  [DRY RUN] Missing: $(basename "$f")${RESET}"
    fi
  done
else
  : > "$FINAL_ZSHRC"

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

  if [[ "$merge_choice" == "y" ]] && ! $DRY_RUN; then
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
  elif $DRY_RUN && [[ "$merge_choice" == "y" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would merge selected categories from backup${RESET}"
  else
    echo -e "${BLUE}Skipping all backup merge prompts per your choice.${RESET}"
  fi
fi

# === Compile .zshrc (after merge so bytecode matches final content) ===
echo -e "${BLUE}▶ Compiling .zshrc for faster startup...${RESET}"
if $DRY_RUN; then
  echo -e "${YELLOW}[DRY RUN] Would compile ~/.zshrc${RESET}"
elif command -v zsh >/dev/null 2>&1; then
  zsh -fc 'zcompile ~/.zshrc' || echo -e "${YELLOW}zcompile failed; continuing without bytecode cache.${RESET}"
else
  echo -e "${RED}Zsh not found during compile step; skipping zcompile.${RESET}"
fi

# === Install Starship configuration ===
if [[ -f "$STARSHIP_SOURCE" ]]; then
  echo -e "${BLUE}▶ Setting up Starship configuration${RESET}"
  mkdir -p "$(dirname "$STARSHIP_CONFIG")"

  if [[ -f "$STARSHIP_CONFIG" ]]; then
    echo -e "${YELLOW}Existing starship.toml found at $STARSHIP_CONFIG${RESET}"
    if [[ $(ask_yes_no "${YELLOW}Replace with Zdots starship config? [y/N]: ${RESET}" N) == y ]]; then
      if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would replace $STARSHIP_CONFIG${RESET}"
      else
        ts="$(date +%Y%m%d%H%M)"
        STARSHIP_BACKUP="$STARSHIP_CONFIG.bak.$ts"
        echo -e "${YELLOW}Backing up existing config to $STARSHIP_BACKUP${RESET}"
        mv "$STARSHIP_CONFIG" "$STARSHIP_BACKUP"
        cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
        echo -e "${BLUE}Starship config installed${RESET}"
      fi
    else
      echo -e "${BLUE}Keeping existing starship config${RESET}"
    fi
  else
    if [[ $(ask_yes_no "${YELLOW}Install Zdots default starship config to $STARSHIP_CONFIG? [y/N]: ${RESET}" N) == y ]]; then
      if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would install starship config to $STARSHIP_CONFIG${RESET}"
      else
        cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
        echo -e "${BLUE}Starship config installed to $STARSHIP_CONFIG${RESET}"
      fi
    else
      echo -e "${BLUE}Skipping starship config installation; no config will be created${RESET}"
    fi
  fi
else
  echo -e "${YELLOW}Starship.toml not found in Zdots directory, skipping${RESET}"
fi

# === Offer default shell switch ===
if [ "$SHELL" != "$(command -v zsh)" ]; then
  if [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    echo -e "${BLUE}Skipping chsh (non-interactive environment detected)${RESET}"
  elif $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would offer to change default shell to zsh${RESET}"
  elif [[ $(ask_yes_no "${YELLOW}Change default shell to Zsh? [Y/n]: ${RESET}" Y) == y ]]; then
    chsh -s "$(command -v zsh)"
    echo -e "${YELLOW}Default shell changed. Takes effect on next login.${RESET}"
  fi
fi

# === Optional immediate switch ===
if [ -n "${BASH_VERSION-}" ]; then
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would offer to switch to Zsh now${RESET}"
  elif [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    echo -e "${BLUE}Skipping immediate shell switch (non-interactive environment)${RESET}"
  elif [[ $(ask_yes_no "${YELLOW}Switch to Zsh now and load your new config? [Y/n]: ${RESET}" Y) == y ]]; then
    echo -e "${BLUE}Switching to Zsh...${RESET}"
    exec zsh -i -c "source ~/.zshrc; exec zsh -l"
  fi
fi

echo -e "${BLUE}✅ Zdots setup complete.${RESET}"
echo -e "${BLUE}System: $OS_TYPE${RESET}"
if [[ "$OS_TYPE" == "linux" ]]; then
  echo -e "${BLUE}Distribution: $DISTRO${RESET}"
fi
echo -e "${YELLOW}💡 Install and configure your terminal with a Mono Nerd Font${RESET}"
echo -e "${YELLOW}   Recommended: FiraCode Nerd Font or similar from https://www.nerdfonts.com${RESET}"
echo -e "${YELLOW}   After installation, make sure to set the font in your terminal preferences or configuration.${RESET}"
