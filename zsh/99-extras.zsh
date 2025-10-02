# ---- User Extras ----
# Place any personal aliases, functions, or experimental configs here.

# ---- Fedora-specific fixes ----
# DNF5 completion compatibility (Fedora 42+)
if command -v dnf5 &>/dev/null && [[ ! -f "$HOME/.zsh/completions/_dnf5" ]]; then
  mkdir -p "$HOME/.zsh/completions"
  # Create a simple dnf5 completion that falls back to dnf completion
  cat > "$HOME/.zsh/completions/_dnf5" << 'EOF'
#compdef dnf5
# DNF5 completion fallback for Fedora 42+
_dnf5() {
  # Use existing dnf completion as base
  local -a dnf_commands
  dnf_commands=(
    'install:install packages'
    'remove:remove packages'
    'update:update packages'
    'upgrade:upgrade packages'
    'search:search packages'
    'info:show package information'
    'list:list packages'
    'history:show transaction history'
    'clean:clean cache'
    'makecache:generate metadata cache'
  )
  
  _arguments -C \
    '1: :->commands' \
    '*:: :->args' && return 0
    
  case $state in
    commands)
      _describe -t commands 'dnf5 commands' dnf_commands
      ;;
    args)
      case $words[1] in
        install|remove|info)
          # Complete available packages
          _arguments '*:packages:_dnf_available_packages'
          ;;
        *)
          _files
          ;;
      esac
      ;;
  esac
}

# Helper function for package completion
_dnf_available_packages() {
  local -a packages
  packages=(${(f)"$(dnf5 list --available 2>/dev/null | awk 'NR>1 {print $1}' | cut -d. -f1 | head -50)"})
  _describe 'packages' packages
}

_dnf5 "$@"
EOF
fi

# Add custom completions to fpath
[[ -d "$HOME/.zsh/completions" ]] && fpath=("$HOME/.zsh/completions" $fpath)

# General use aliases updated for eza
alias ls='eza' # Basic replacement for ls with eza
alias l='eza --long -bF' # Extended details with binary sizes and type indicators
alias ll='eza --long -a' # Long format, including hidden files
alias llm='eza --long -a --sort=modified' # Long format, including hidden files
alias la='eza -a --group-directories-first' # Show all files, with directories listed first
alias lx='eza -a --group-directories-first --extended' # Show all files and extended attributes
alias tree='eza --tree' # Tree view
alias lS='eza --oneline' # Display one entry per line

# New aliases than exa-zsh
alias lT='eza --tree --long' # Tree view with extended details
alias lr='eza --recurse --all' # Recursively list all files, including hidden ones
alias lg='eza --grid --color=always' # Display entries as a grid with color
alias ld='eza --only-dirs' # List only directories
alias lf='eza --only-files' # List only files
alias lC='eza --color-scale=size --long' # Use color scale based on file size
alias li='eza --icons=always --grid' # Display with icons in grid format
alias lh='eza --hyperlink --all' # Display all entries as hyperlinks
alias lX='eza --across' # Sort the grid across, rather than downwards
alias lt='eza --long --sort=type' # Sort by file type in long format
alias lsize='eza --long --sort=size' # Sort by size in long format
alias lmod='eza --long --modified --sort=modified' # Sort by modification date in long format

# Advanced filtering and display options
alias ldepth='eza --level=2' # Limit recursion depth to 2
alias lignore='eza --git-ignore' # Ignore files mentioned in .gitignore
alias lcontext='eza --long --context' # Show security context

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Fedora-specific aliases
alias dnf='dnf5' # Use dnf5 by default
alias dnfi='dnf5 install'
alias dnfs='dnf5 search'
alias dnfu='dnf5 update'
alias dnfr='dnf5 remove'
alias dnfl='dnf5 list'
alias dnfh='dnf5 history'

# System information
alias sysinfo='hostnamectl && echo && dnf5 --version'
alias ports='ss -tuln'
alias services='systemctl list-units --type=service'

# Niri-specific aliases (when running niri)
if [[ "$XDG_CURRENT_DESKTOP" == "niri" ]]; then
  # Niri window management
  alias niri-msg='niri msg'
  alias niri-outputs='niri msg outputs'
  alias niri-workspaces='niri msg workspaces'
  alias niri-windows='niri msg windows'
  alias niri-version='niri msg version'
  
  # Wayland clipboard helpers (for niri + cliphist setup)
  alias cb='wl-copy'
  alias cbp='wl-paste'
  alias cbh='cliphist list | fzf --preview "cliphist decode {}" --preview-window=up:3:wrap | cliphist decode | wl-copy'
  alias cbclear='cliphist wipe'
  
  # Screenshot helpers
  alias ss='niri msg action screenshot'
  alias ssw='niri msg action screenshot-window'
  alias sss='niri msg action screenshot-screen'
fi