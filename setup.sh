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

  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would install $shell_name${RESET}"
    return 0
  fi

  echo -e "${YELLOW}Installing ${shell_name}...${RESET}"
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

# === Install shells and decide which to configure ===
has_zsh=false
has_fish=false
configure_zsh=false
configure_fish=false
command -v zsh >/dev/null 2>&1 && has_zsh=true
command -v fish >/dev/null 2>&1 && has_fish=true

if ! $has_zsh; then
  if [[ $(ask_yes_no "${YELLOW}Zsh is not installed. Install and configure it? [Y/n]: ${RESET}" Y) == y ]]; then
    install_shell_if_missing zsh && { has_zsh=true; configure_zsh=true; }
  else
    echo -e "${BLUE}Skipping Zsh.${RESET}"
  fi
else
  echo -e "${BLUE}Zsh is already installed.${RESET}"
  if [[ $(ask_yes_no "${YELLOW}Configure Zsh with Zdots? [Y/n]: ${RESET}" Y) == y ]]; then
    configure_zsh=true
  fi
fi

if ! $has_fish; then
  if [[ $(ask_yes_no "${YELLOW}Fish is not installed. Install and configure it? [Y/n]: ${RESET}" Y) == y ]]; then
    install_shell_if_missing fish && { has_fish=true; configure_fish=true; }
  else
    echo -e "${BLUE}Skipping Fish.${RESET}"
  fi
else
  echo -e "${BLUE}Fish is already installed.${RESET}"
  if [[ $(ask_yes_no "${YELLOW}Configure Fish with Zdots? [Y/n]: ${RESET}" Y) == y ]]; then
    configure_fish=true
  fi
fi

if ! $configure_zsh && ! $configure_fish; then
  echo -e "${RED}No shells selected for configuration. Nothing to do.${RESET}"
  exit 0
fi

# =====================================================================
# ZSH SETUP
# =====================================================================
if $configure_zsh; then
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

# === Port fish content to zsh ===
FISH_SOURCE_FOR_PORT=""
if [[ -d "$HOME/.config/fish/conf.d" ]] && ! $configure_fish; then
  FISH_SOURCE_FOR_PORT="$HOME/.config/fish/conf.d"
fi

if [[ -n "$FISH_SOURCE_FOR_PORT" ]] && ! $DRY_RUN; then
  if [[ $(ask_yes_no "${YELLOW}Port aliases/exports/PATH from fish config to zsh? [y/N]: ${RESET}" N) == y ]]; then
    fish_imported=false
    maybe_add_fish_footer() {
      if [ "$fish_imported" = false ]; then
        { echo ""; echo "# --- Imported from fish config on $(date) ---"; } >> "$FINAL_ZSHRC"
        fish_imported=true
      fi
    }

    alias_count=0
    export_count=0
    path_count=0

    for conf in "$FISH_SOURCE_FOR_PORT"/*.fish; do
      [[ -f "$conf" ]] || continue

      # alias foo 'bar' → alias foo='bar'
      grep -E "^alias " "$conf" 2>/dev/null | while IFS= read -r line; do
        rest="${line#alias }"
        name="${rest%% *}"
        value="${rest#* }"
        value="${value#\'}"
        value="${value%\'}"
        value="${value#\"}"
        value="${value%\"}"
        converted="alias ${name}='${value}'"
        if ! grep -Fxq "$converted" "$FINAL_ZSHRC"; then
          maybe_add_fish_footer
          echo "$converted" >> "$FINAL_ZSHRC"
        fi
      done
      alias_count=$((alias_count + $(grep -cE "^alias " "$conf" 2>/dev/null || true)))

      # set -gx FOO bar → export FOO=bar
      grep -E "^set -gx " "$conf" 2>/dev/null | while IFS= read -r line; do
        rest="${line#set -gx }"
        var="${rest%% *}"
        value="${rest#* }"
        converted="export ${var}=${value}"
        if ! grep -Fxq "$converted" "$FINAL_ZSHRC"; then
          maybe_add_fish_footer
          echo "$converted" >> "$FINAL_ZSHRC"
        fi
      done
      export_count=$((export_count + $(grep -cE "^set -gx " "$conf" 2>/dev/null || true)))

      # fish_add_path /foo → PATH=/foo:$PATH
      grep -E "^fish_add_path " "$conf" 2>/dev/null | while IFS= read -r line; do
        rest="${line#fish_add_path }"
        rest="${rest#-g }"
        rest="${rest#-gP }"
        converted="PATH=${rest}:\$PATH"
        if ! grep -Fxq "$converted" "$FINAL_ZSHRC"; then
          maybe_add_fish_footer
          echo "$converted" >> "$FINAL_ZSHRC"
        fi
      done
      path_count=$((path_count + $(grep -cE "^fish_add_path " "$conf" 2>/dev/null || true)))
    done

    total=$((alias_count + export_count + path_count))
    if [[ "$total" -gt 0 ]]; then
      echo -e "${GREEN}  ✔ Ported from fish config${RESET}"
      echo -e "${BLUE}    ${alias_count} aliases, ${export_count} exports, ${path_count} PATH entries${RESET}"
    else
      echo -e "${BLUE}  No portable content found in fish config.${RESET}"
    fi
  fi
elif $DRY_RUN && [[ -n "$FISH_SOURCE_FOR_PORT" ]]; then
  echo -e "${YELLOW}[DRY RUN] Would offer to port fish aliases/exports/PATH to zsh${RESET}"
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

fi # end configure_zsh

# =====================================================================
# FISH SETUP
# =====================================================================
if $configure_fish; then
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

# === Port zsh content to fish ===
# Look for a zsh backup or existing .zshrc to offer porting aliases/exports/PATH
ZSH_SOURCE_FOR_PORT=""
if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
  ZSH_SOURCE_FOR_PORT="$BACKUP_FILE"
elif [[ -f "$HOME/.zshrc" ]] && ! $configure_zsh; then
  ZSH_SOURCE_FOR_PORT="$HOME/.zshrc"
fi

if [[ -n "$ZSH_SOURCE_FOR_PORT" ]] && ! $DRY_RUN; then
  if [[ $(ask_yes_no "${YELLOW}Port aliases/exports/PATH from zsh config to fish? [y/N]: ${RESET}" N) == y ]]; then
    FISH_IMPORT="$FISH_CONFIG_DIR/conf.d/98-imported.fish"

    {
      echo "# --- Imported from zsh config on $(date) ---"
    } > "$FISH_IMPORT"

    # Aliases: alias foo='bar' → alias foo 'bar'
    grep -E '^alias ' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null | while IFS= read -r line; do
      name="${line#alias }"
      name="${name%%=*}"
      value="${line#*=}"
      value="${value#\'}"
      value="${value%\'}"
      value="${value#\"}"
      value="${value%\"}"
      echo "alias $name '$value'" >> "$FISH_IMPORT"
    done
    alias_count=$(grep -cE '^alias ' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null || true)

    # Exports: export FOO=bar → set -gx FOO bar
    grep -E '^export [A-Za-z_]+=' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null | while IFS= read -r line; do
      rest="${line#export }"
      var="${rest%%=*}"
      value="${rest#*=}"
      value="${value#\'}"
      value="${value%\'}"
      value="${value#\"}"
      value="${value%\"}"
      echo "set -gx $var $value" >> "$FISH_IMPORT"
    done
    export_count=$(grep -cE '^export [A-Za-z_]+=' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null || true)

    # PATH: PATH=/foo/bar:$PATH → fish_add_path /foo/bar
    grep -E '^PATH=' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null | while IFS= read -r line; do
      value="${line#PATH=}"
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      value="${value%:\$PATH}"
      if [[ "$value" != *'$'* && -n "$value" ]]; then
        echo "fish_add_path $value" >> "$FISH_IMPORT"
      fi
    done
    path_count=$(grep -cE '^PATH=' "$ZSH_SOURCE_FOR_PORT" 2>/dev/null || true)

    total=$((alias_count + export_count + path_count))
    if [[ "$total" -gt 0 ]]; then
      echo -e "${GREEN}  ✔ Ported to $FISH_IMPORT${RESET}"
      echo -e "${BLUE}    ${alias_count} aliases, ${export_count} exports, ${path_count} PATH entries${RESET}"
    else
      echo -e "${BLUE}  No portable content found in zsh config.${RESET}"
      rm -f "$FISH_IMPORT"
    fi
  fi
elif $DRY_RUN && [[ -n "$ZSH_SOURCE_FOR_PORT" ]]; then
  echo -e "${YELLOW}[DRY RUN] Would offer to port zsh aliases/exports/PATH to fish${RESET}"
fi

fi # end configure_fish

# =====================================================================
# SHARED: Starship configuration
# =====================================================================
if [[ -f "$STARSHIP_SOURCE" ]]; then
  echo ""
  echo -e "${BLUE}▶ Setting up Starship configuration${RESET}"
  mkdir -p "$(dirname "$STARSHIP_CONFIG")"

  if [[ -f "$STARSHIP_CONFIG" ]]; then
    echo -e "${YELLOW}Existing starship.toml found at $STARSHIP_CONFIG${RESET}"
    if [[ $(ask_yes_no "${YELLOW}Replace with Zdots starship config? (existing will be backed up) [y/N]: ${RESET}" N) == y ]]; then
      if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would back up and replace $STARSHIP_CONFIG${RESET}"
      else
        ts="$(date +%Y%m%d%H%M)"
        STARSHIP_BACKUP="$STARSHIP_CONFIG.bak.$ts"
        mv "$STARSHIP_CONFIG" "$STARSHIP_BACKUP"
        cp "$STARSHIP_SOURCE" "$STARSHIP_CONFIG"
        starship_status="installed (replaced)"
        echo -e "${GREEN}  ✔ Starship config installed${RESET}"
        echo -e "${BLUE}    Backup: $STARSHIP_BACKUP${RESET}"
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
if $configure_zsh; then
  if $DRY_RUN; then
    echo -e "${BLUE}   Zsh:      ${zsh_module_count} modules found${RESET}"
  else
    compile_label=""
    $compile_ok && compile_label=", compiled"
    echo -e "${BLUE}   Zsh:      ${zsh_module_count} modules${compile_label} → ~/.zshrc${RESET}"
  fi
elif $has_zsh; then
  echo -e "${BLUE}   Zsh:      installed (not configured)${RESET}"
fi
if $configure_fish; then
  if $DRY_RUN; then
    echo -e "${BLUE}   Fish:     ${fish_module_count} modules found${RESET}"
  else
    echo -e "${BLUE}   Fish:     ${fish_module_count} modules → ~/.config/fish/${RESET}"
  fi
elif $has_fish; then
  echo -e "${BLUE}   Fish:     installed (not configured)${RESET}"
fi
echo -e "${BLUE}   Starship: ${starship_status}${RESET}"
[[ -n "$BACKUP_FILE" ]] && echo -e "${BLUE}   Backup:   $BACKUP_FILE${RESET}"
echo ""
echo -e "${YELLOW}💡 Tip: Install a Mono Nerd Font for best prompt rendering${RESET}"
echo -e "${YELLOW}   https://www.nerdfonts.com${RESET}"
if $has_zsh && $has_fish; then
  echo -e "${BLUE}   Switch anytime: type ${GREEN}zsh${BLUE} or ${GREEN}fish${RESET}"
fi
echo ""

# === Offer default shell switch ===
current_shell="$(basename "$SHELL")"
chosen_default="$current_shell"
if [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
  echo -e "${BLUE}Skipping chsh (non-interactive environment)${RESET}"
elif $DRY_RUN; then
  echo -e "${YELLOW}[DRY RUN] Would offer to change default shell${RESET}"
else
  if $has_zsh && [[ "$current_shell" != "zsh" ]]; then
    if [[ $(ask_yes_no "${YELLOW}Set Zsh as default shell? [y/N]: ${RESET}" N) == y ]]; then
      chsh -s "$(command -v zsh)"
      chosen_default="zsh"
      echo -e "${GREEN}Default shell changed to Zsh.${RESET}"
    fi
  fi
  if $has_fish && [[ "$chosen_default" != "fish" && "$current_shell" != "fish" ]]; then
    if [[ $(ask_yes_no "${YELLOW}Set Fish as default shell? [y/N]: ${RESET}" N) == y ]]; then
      chsh -s "$(command -v fish)"
      chosen_default="fish"
      echo -e "${GREEN}Default shell changed to Fish.${RESET}"
    fi
  fi
fi

# === Optional immediate switch ===
if [ -n "${BASH_VERSION-}" ]; then
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would offer to launch zsh or fish${RESET}"
  elif [[ -n "${ZDOTS_NONINTERACTIVE:-}" || ! -t 0 ]]; then
    echo -e "${BLUE}Skipping immediate shell switch (non-interactive)${RESET}"
  elif [[ "$chosen_default" == "fish" ]]; then
    if $has_fish && [[ $(ask_yes_no "${YELLOW}Launch Fish now? [Y/n]: ${RESET}" Y) == y ]]; then
      echo -e "${BLUE}Launching Fish...${RESET}"
      exec fish -l
    elif $has_zsh && [[ $(ask_yes_no "${YELLOW}Launch Zsh now? [y/N]: ${RESET}" N) == y ]]; then
      echo -e "${BLUE}Launching Zsh...${RESET}"
      exec zsh -i -c "source ~/.zshrc; exec zsh -l"
    fi
  else
    if $has_zsh && [[ $(ask_yes_no "${YELLOW}Launch Zsh now? [Y/n]: ${RESET}" Y) == y ]]; then
      echo -e "${BLUE}Launching Zsh...${RESET}"
      exec zsh -i -c "source ~/.zshrc; exec zsh -l"
    elif $has_fish && [[ $(ask_yes_no "${YELLOW}Launch Fish now? [y/N]: ${RESET}" N) == y ]]; then
      echo -e "${BLUE}Launching Fish...${RESET}"
      exec fish -l
    fi
  fi
fi
