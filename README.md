# Zdots — Dual-Shell Dotfiles (Zsh + Fish)

![Zsh Startup](https://img.shields.io/badge/zsh%20startup-35ms-brightgreen)
![Fish Startup](https://img.shields.io/badge/fish%20startup-8ms-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

A clean, reproducible shell setup for both **Zsh** and **Fish** — designed for speed, portability, and modern terminal workflows. One repo, two shells, switch anytime.

## 🚀 Features

**Shared across both shells:**
- Starship prompt
- zoxide smart directory jumping
- Lazy-loaded NVM with dynamic PATH
- Cross-distro installation (pacman/apt/dnf/yum/zypper/apk/nix/xbps/emerge)
- `--dry-run` mode, non-interactive/CI support, backup merge flow

**Zsh** (~35ms startup):
- Modular config in `zsh/` assembled into a single `.zshrc`
- Turbo-loaded plugins via Zinit (fzf-tab, syntax-highlighting, autosuggestions)
- Fish-style autosuggestions: `match_prev_cmd → history → completion`
- Alt-→ partial word accept, compiled bytecode cache

**Fish** (~8ms startup):
- Modular config in `fish/conf.d/` and `fish/functions/`
- Autosuggestions, syntax highlighting, and completions are all built-in
- Zero plugins required

## 🛠 Installation
```bash
git clone https://github.com/purian23/zdots.git ~/.zdots
cd ~/.zdots
./setup.sh
```
The installer configures **both** Zsh and Fish. Switch between them anytime:
```bash
zsh    # launch Zsh
fish   # launch Fish
```
Preview without making changes:
```bash
./setup.sh --dry-run
```

Notes:
- Both shells are installed automatically if missing.
- Starship config is shared between both shells.
- In non-interactive environments, `chsh` and shell-switch are automatically skipped.
- Logging: `~/.cache/zdots-setup.log`

### Environment variables
| Variable | Purpose |
|----------|---------|
| `ZDOTS_YES=1` | Answer "yes" to all prompts |
| `ZDOTS_NO=1` | Answer "no" to all prompts |
| `ZDOTS_NONINTERACTIVE=1` | Use defaults; skip `chsh` and shell-switch |
| `ZDOTS_PM=<name>` | Force a package manager (e.g. `apk`, `nix`, `xbps`) |
| `ZDOTS_MERGE=all\|yes\|no` | Control backup merge behavior |
| `ZDOTS_LOGFILE=<path>` | Override the setup log path |

## 🧩 VS Code Compatibility
Add to `settings.json` for Zsh:
```json
"terminal.integrated.profiles.linux": {
  "zsh": { "path": "/bin/zsh", "args": ["-l"] },
  "fish": { "path": "/usr/bin/fish", "args": ["-l"] }
},
"terminal.integrated.defaultProfile.linux": "zsh"
```

## 🧪 Performance
```bash
# Zsh
time zsh -i -c exit    # ~0.035s

# Fish
time fish -c exit      # ~0.008s
```
Profile Zsh plugins: `zmodload zsh/zprof` at top of `.zshrc`, then `zprof`.

## 📦 Recommended packages (not auto-installed)
```text
bat, eza, fzf, p7zip, starship, unrar, unzip, zoxide
```

## 🧰 Distro support
Auto-detects: pacman, apt/apt-get, dnf, zypper, yum, apk, nix-env, xbps-install, emerge

Tested on recent Arch, Ubuntu, Fedora 42+, Alpine; other distros welcome via PRs.

## Uninstall
```bash
# Zsh
mv ~/.zshrc ~/.zshrc.generated.bak
mv ~/.zshrc.bak.YYYYMMDDHHMM ~/.zshrc

# Fish
rm ~/.config/fish/conf.d/{00-options,10-path,20-nvm,30-prompt,40-zoxide,99-extras}.fish
rm ~/.config/fish/functions/{nvm,node,npm,npx}.fish
```

## 🤝 Contributions
Feel free to fork, tweak, or submit pull requests.  
This setup is built for clarity, reproducibility, and performance — contributions that preserve those values are welcome.
