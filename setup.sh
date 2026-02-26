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
GREEN="\033[1;32m"
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
ZSH_MODULE_DIR="$SCRIPT_DIR/zsh"
FISH_MODULE_DIR="$SCRIPT_DIR/fish"
FINAL_ZSHRC="$HOME/.zshrc"
FISH_CONFIG_DIR="$HOME/.config/fish"
BACKUP_FILE=""
STARSHIP_CONFIG="$HOME/.config/starship.toml"
STARSHIP_SOURCE="$SCRIPT_DIR/starship.toml"

# === Status tracking ===
zsh_module_count=0
fish_module_count=0
compile_ok=false
starship_status="not available"

# === Prompt helper ===
ask_yes_no() {
  local prompt="$1" default_answer="$2" reply
  if [[ "${ZDOTS_NO:-}" == "1" ]]; then echo y | tr 'yn' 'ny'; return; fi
  if [[ "${ZDOTS_YES:-}" == "1" ]]; then echo y; return; fi
  if [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    [[ "$default_answer" =~ ^[Yy]$ ]] && echo y || echo n
    return
  fi
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

detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    echo "${ID:-unknown}"
  elif [[ -f /etc/fedora-release ]]; then echo "fedora"
  elif [[ -f /etc/debian_version ]]; then echo "debian"
  elif [[ -f /etc/arch-release ]]; then echo "arch"
  else echo "unknown"
  fi
}

OS_TYPE="$(detect_os)"
DISTRO="$(detect_distro)"

if [[ "$OS_TYPE" == "linux" ]]; then
  echo -e "${BLUE}Detected: $DISTRO Linux${RESET}"
  if [[ "$DISTRO" == "fedora" && -f /etc/fedora-release ]]; then
    FEDORA_VERSION=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
    echo -e "${BLUE}Fedora version: $FEDORA_VERSION${RESET}"
  fi
fi

# === Sudo helpers ===
check_sudo() {
  [[ "$OS_TYPE" == "macos" ]] && return 0
  [[ "$(id -u)" -eq 0 ]] && return 0
  if ! command -v sudo >/dev/null 2>&1; then
    echo -e "${RED}sudo is required but not found.${RESET}"
    return 1
  fi
  return 0
}

maybe_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# === Generic shell installer ===
install_shell_if_missing() {
  local shell_name="$1"

  if command -v "$shell_name" >/dev/null 2>&1; then
    echo -e "${BLUE}${shell_name} is already installed.${RESET}"
    return 0
  fi

  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would install $shell_name${RESET}"
    return 0
  fi

  echo -e "${YELLOW}${shell_name} not found. Attempting to install...${RESET}"
  if [[ "$OS_TYPE" == "linux" ]] && ! check_sudo; then return 1; fi

  local pm="${ZDOTS_PM:-}"
  if [[ -n "$pm" ]]; then
    case "$pm" in
      brew|homebrew) brew install "$shell_name" && return 0 ;;
      pacman) maybe_sudo pacman -S --needed --noconfirm "$shell_name" && return 0 ;;
      apt|apt-get) maybe_sudo apt-get update && maybe_sudo apt-get install -y "$shell_name" && return 0 ;;
      dnf) maybe_sudo dnf install -y "$shell_name" && return 0 ;;
      yum) maybe_sudo yum install -y "$shell_name" && return 0 ;;
      zypper) maybe_sudo zypper -n install "$shell_name" && return 0 ;;
      apk) maybe_sudo apk add "$shell_name" && return 0 ;;
      nix|nix-env) nix-env -iA "nixpkgs.$shell_name" && return 0 ;;
      xbps) maybe_sudo xbps-install -y "$shell_name" && return 0 ;;
      emerge|portage) maybe_sudo emerge --ask=n "$shell_name" && return 0 ;;
    esac
  fi

  if [[ "$OS_TYPE" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install "$shell_name" || true
    else
      echo -e "${YELLOW}Homebrew not found. Installing Homebrew first...${RESET}"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
      if command -v brew >/dev/null 2>&1; then brew install "$shell_name" || true; fi
    fi
  elif [[ "$OS_TYPE" == "linux" ]]; then
    if command -v pacman >/dev/null 2>&1; then
      maybe_sudo pacman -S --needed --noconfirm "$shell_name" || true
    elif command -v apt-get >/dev/null 2>&1; then
      { maybe_sudo apt-get update && maybe_sudo apt-get install -y "$shell_name"; } || true
    elif command -v dnf >/dev/null 2>&1; then
      maybe_sudo dnf install -y "$shell_name" || true
    elif command -v zypper >/dev/null 2>&1; then
      maybe_sudo zypper -n install "$shell_name" || true
    elif command -v yum >/dev/null 2>&1; then
      maybe_sudo yum install -y "$shell_name" || true
    elif command -v apk >/dev/null 2>&1; then
      maybe_sudo apk add "$shell_name" || true
    elif command -v nix-env >/dev/null 2>&1; then
      nix-env -iA "nixpkgs.$shell_name" || true
    elif command -v xbps-install >/dev/null 2>&1; then
      maybe_sudo xbps-install -y "$shell_name" || true
    elif command -v emerge >/dev/null 2>&1; then
      maybe_sudo emerge --ask=n "$shell_name" || true
    else
      echo -e "${RED}No supported package manager found for $shell_name.${RESET}"
      return 1
    fi
  fi

  if command -v "$shell_name" >/dev/null 2>&1; then
    echo -e "${BLUE}${shell_name} installed successfully.${RESET}"
  else
    echo -e "${RED}${shell_name} installation failed. Please install manually.${RESET}"
    return 1
  fi
}

# === Install both shells ===
install_shell_if_missing zsh || true
install_shell_if_missing fish || true

# =====================================================================
# ZSH SETUP
# =====================================================================
echo ""
echo -e "${BLUE}▶ Setting up Zsh${RESET}"

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
declare -a modules=()
if [[ -f "$ZSH_MODULE_DIR/order.txt" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    modules+=("$ZSH_MODULE_DIR/$line")
  done < "$ZSH_MODULE_DIR/order.txt"
else
  for f in "$ZSH_MODULE_DIR"/*.zsh; do
    [[ -f "$f" ]] && modules+=("$f")
  done
fi

if $DRY_RUN; then
  for f in "${modules[@]}"; do
    [[ -f "$f" ]] && zsh_module_count=$((zsh_module_count + 1))
  done
  echo -e "${BLUE}  ✔ ${zsh_module_count} zsh modules would be assembled${RESET}"
else
  : > "$FINAL_ZSHRC"
  for f in "${modules[@]}"; do
    if [[ -f "$f" ]]; then
      cat "$f" >> "$FINAL_ZSHRC"
      echo "" >> "$FINAL_ZSHRC"
      zsh_module_count=$((zsh_module_count + 1))
    else
      echo -e "${RED}  ✗ Missing: $(basename "$f")${RESET}"
    fi
  done
  echo -e "${GREEN}  ✔ ${zsh_module_count} zsh modules assembled${RESET}"
fi

# === Merge from backup ===
if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
  merge_mode="${ZDOTS_MERGE:-}"
  merge_choice=""
  merge_all=0
  merge_mode_lower="$(echo "$merge_mode" | tr '[:upper:]' '[:lower:]')"
  case "$merge_mode_lower" in
    0|no|none) merge_choice="n" ;;
    1|yes|interactive) merge_choice="y" ;;
    all) merge_choice="y"; merge_all=1 ;;
  esac
  if [[ -z "$merge_choice" ]]; then
    if [[ $(ask_yes_no "${YELLOW}Merge content from previous .zshrc backup? [y/N]: ${RESET}" N) == y ]]; then
      merge_choice="y"
    else
      merge_choice="n"
    fi
  fi

  if [[ "$merge_choice" == "y" ]] && ! $DRY_RUN; then
    imported_any=false
    maybe_add_footer() {
      if [ "$imported_any" = false ]; then
        { echo ""; echo "# --- Imported from previous .zshrc backup on $(date) ---"; } >> "$FINAL_ZSHRC"
        imported_any=true
      fi
    }
    if (( merge_all == 0 )); then
      [[ $(ask_yes_no "${YELLOW}Merge all categories automatically? [y/N]: ${RESET}" N) == y ]] && merge_all=1
    fi
    for section in aliases exports PATH functions; do
      case $section in
        aliases)
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge aliases? [Y/n]: ${RESET}" Y) == y ]]; then
            grep -E '^alias ' "$BACKUP_FILE" 2>/dev/null | while read -r line; do
              grep -Fxq "$line" "$FINAL_ZSHRC" || { maybe_add_footer; echo "$line" >> "$FINAL_ZSHRC"; }
            done
          fi ;;
        exports)
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge exports? [Y/n]: ${RESET}" Y) == y ]]; then
            grep -E '^export ' "$BACKUP_FILE" 2>/dev/null | while read -r line; do
              grep -Fxq "$line" "$FINAL_ZSHRC" || { maybe_add_footer; echo "$line" >> "$FINAL_ZSHRC"; }
            done
          fi ;;
        PATH)
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge PATH modifications? [Y/n]: ${RESET}" Y) == y ]]; then
            grep -E '^PATH=' "$BACKUP_FILE" 2>/dev/null | while read -r line; do
              grep -Fxq "$line" "$FINAL_ZSHRC" || { maybe_add_footer; echo "$line" >> "$FINAL_ZSHRC"; }
            done
          fi ;;
        functions)
          if (( merge_all )) || [[ $(ask_yes_no "${YELLOW}Merge functions? [Y/n]: ${RESET}" Y) == y ]]; then
            awk '
              /^([[:space:]]*function[[:space:]]+[a-zA-Z0-9_]+\s*\(\)\s*\{|^[a-zA-Z0-9_]+\s*\(\)\s*\{)/ {infunc=1; fn=$0 ORS; next}
              infunc {fn=fn $0 ORS; if (/^\}/) {print fn; infunc=0}}
            ' "$BACKUP_FILE" | while IFS= read -r block; do
              grep -Fq "$block" "$FINAL_ZSHRC" || { maybe_add_footer; printf "%s\n" "$block" >> "$FINAL_ZSHRC"; }
            done
          fi ;;
      esac
    done
  elif $DRY_RUN && [[ "$merge_choice" == "y" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would merge from backup${RESET}"
  else
    echo -e "${BLUE}No content merged from backup.${RESET}"
  fi
fi

# === Compile .zshrc ===
if $DRY_RUN; then
  echo -e "${YELLOW}[DRY RUN] Would compile ~/.zshrc${RESET}"
elif command -v zsh >/dev/null 2>&1; then
  if zsh -fc 'zcompile ~/.zshrc' 2>/dev/null; then
    compile_ok=true
    echo -e "${GREEN}  ✔ .zshrc compiled${RESET}"
  else
    echo -e "${YELLOW}  ⚠ zcompile failed${RESET}"
  fi
fi

# =====================================================================
# FISH SETUP
# =====================================================================
echo ""
echo -e "${BLUE}▶ Setting up Fish${RESET}"

if [[ -d "$FISH_MODULE_DIR" ]]; then
  if $DRY_RUN; then
    fish_module_count=$(find "$FISH_MODULE_DIR/conf.d" -name '*.fish' 2>/dev/null | wc -l)
    fish_module_count=$((fish_module_count + $(find "$FISH_MODULE_DIR/functions" -name '*.fish' 2>/dev/null | wc -l)))
    echo -e "${BLUE}  ✔ ${fish_module_count} fish modules would be deployed${RESET}"
  else
    mkdir -p "$FISH_CONFIG_DIR/conf.d" "$FISH_CONFIG_DIR/functions"

    for f in "$FISH_MODULE_DIR"/conf.d/*.fish; do
      [[ -f "$f" ]] || continue
      cp "$f" "$FISH_CONFIG_DIR/conf.d/"
      fish_module_count=$((fish_module_count + 1))
    done

    for f in "$FISH_MODULE_DIR"/functions/*.fish; do
      [[ -f "$f" ]] || continue
      cp "$f" "$FISH_CONFIG_DIR/functions/"
      fish_module_count=$((fish_module_count + 1))
    done

    echo -e "${GREEN}  ✔ ${fish_module_count} fish modules deployed${RESET}"
  fi
else
  echo -e "${YELLOW}  No fish/ directory found, skipping fish config${RESET}"
fi

# =====================================================================
# SHARED: Starship configuration
# =====================================================================
if [[ -f "$STARSHIP_SOURCE" ]]; then
  echo ""
  echo -e "${BLUE}▶ Setting up Starship configuration${RESET}"
  mkdir -p "$(dirname "$STARSHIP_CONFIG")"

  if [[ -f "$STARSHIP_CONFIG" ]]; then
    echo -e "${YELLOW}Existing starship.toml found at $STARSHIP_CONFIG${RESET}"
    if [[ $(ask_yes_no "${YELLOW}Replace with Zdots starship config? [y/N]: ${RESET}" N) == y ]]; then
      if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would replace $STARSHIP_CONFIG${RESET}"
      else
        ts="$(date +%Y%m%d%H%M)"
        mv "$STARSHIP_CONFIG" "$STARSHIP_CONFIG.bak.$ts"
        cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
        starship_status="installed (replaced)"
        echo -e "${GREEN}  ✔ Starship config installed${RESET}"
      fi
    else
      starship_status="kept existing"
      echo -e "${BLUE}  Keeping existing starship config${RESET}"
    fi
  else
    if [[ $(ask_yes_no "${YELLOW}Install Zdots starship config? [y/N]: ${RESET}" N) == y ]]; then
      if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would install starship config${RESET}"
      else
        cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
        starship_status="installed"
        echo -e "${GREEN}  ✔ Starship config installed${RESET}"
      fi
    else
      starship_status="skipped"
      echo -e "${BLUE}  Starship config skipped${RESET}"
    fi
  fi
fi

# =====================================================================
# SUMMARY
# =====================================================================
echo ""
echo -e "${GREEN}✅ Zdots setup complete!${RESET}"
if [[ "$OS_TYPE" == "linux" ]]; then
  echo -e "${BLUE}   System:   $OS_TYPE ($DISTRO)${RESET}"
else
  echo -e "${BLUE}   System:   $OS_TYPE${RESET}"
fi
if $DRY_RUN; then
  echo -e "${BLUE}   Zsh:      ${zsh_module_count} modules found${RESET}"
  echo -e "${BLUE}   Fish:     ${fish_module_count} modules found${RESET}"
else
  compile_label=""
  $compile_ok && compile_label=", compiled"
  echo -e "${BLUE}   Zsh:      ${zsh_module_count} modules${compile_label} → ~/.zshrc${RESET}"
  echo -e "${BLUE}   Fish:     ${fish_module_count} modules → ~/.config/fish/${RESET}"
fi
echo -e "${BLUE}   Starship: ${starship_status}${RESET}"
[[ -n "$BACKUP_FILE" ]] && echo -e "${BLUE}   Backup:   $BACKUP_FILE${RESET}"
echo ""
echo -e "${YELLOW}💡 Tip: Install a Mono Nerd Font for best prompt rendering${RESET}"
echo -e "${YELLOW}   https://www.nerdfonts.com${RESET}"
echo -e "${BLUE}   Switch anytime: type ${GREEN}zsh${BLUE} or ${GREEN}fish${RESET}"
echo ""

# === Offer default shell switch ===
current_shell="$(basename "$SHELL")"
if [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
  echo -e "${BLUE}Skipping chsh (non-interactive environment)${RESET}"
elif $DRY_RUN; then
  echo -e "${YELLOW}[DRY RUN] Would offer to change default shell${RESET}"
elif [[ "$current_shell" != "zsh" && "$current_shell" != "fish" ]]; then
  echo -e "${YELLOW}Your default shell is $current_shell.${RESET}"
  if [[ $(ask_yes_no "${YELLOW}Change default shell to Zsh? [y/N]: ${RESET}" N) == y ]]; then
    chsh -s "$(command -v zsh)"
    echo -e "${GREEN}Default shell changed to Zsh.${RESET}"
  elif [[ $(ask_yes_no "${YELLOW}Change default shell to Fish? [y/N]: ${RESET}" N) == y ]]; then
    chsh -s "$(command -v fish)"
    echo -e "${GREEN}Default shell changed to Fish.${RESET}"
  fi
fi

# === Optional immediate switch ===
if [ -n "${BASH_VERSION-}" ]; then
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would offer to launch zsh or fish${RESET}"
  elif [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    echo -e "${BLUE}Skipping immediate shell switch (non-interactive)${RESET}"
  elif [[ $(ask_yes_no "${YELLOW}Launch Zsh now? [Y/n]: ${RESET}" Y) == y ]]; then
    echo -e "${BLUE}Launching Zsh...${RESET}"
    exec zsh -i -c "source ~/.zshrc; exec zsh -l"
  elif [[ $(ask_yes_no "${YELLOW}Launch Fish now? [y/N]: ${RESET}" N) == y ]]; then
    echo -e "${BLUE}Launching Fish...${RESET}"
    exec fish -l
  fi
fi
