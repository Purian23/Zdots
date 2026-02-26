# Modular ZSH Dotfiles (Zdots)

![Shell Benchmark](https://img.shields.io/badge/zsh%20startup%20time-45ms-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

A clean, reproducible Zsh setup designed for speed, system hygiene, and portability.  
Includes fzf-tab, zoxide, starship, and lazy-loaded NVM — optimized for modern terminal workflows.

## 🚀 Features
- Modular source files in `~/.zdots/zsh/`
- fzf-tab fuzzy completions  
- zoxide smart directory jumping  
- Starship prompt  
- Lazy-loaded NVM with dynamic PATH  
- Alias and install script friendly
- VS Code compatibility  
- Sub-50ms shell startup time  
- Backs up your existing ~/.zshrc to ~/.zshrc.bak.TIMESTAMP
- Concatenates Zdots' modular files into a single `.zshrc` for speed
- Optional merge from your previous `~/.zshrc` (aliases, exports, PATH changes, functions)
- Cross-distro zsh installation (auto-detects pacman/apt/dnf/yum/zypper/apk/nix/xbps/emerge)
- All prompts support non-interactive/CI flags and are logged to `~/.cache/zdots-setup.log`
- `--dry-run` mode to preview changes without modifying anything

## 🛠 Installation
Clone the repo and run the setup script:
```bash
git clone https://github.com/purian23/zdots.git ~/.zdots
cd ~/.zdots
./setup.sh
```
Then reload your shell:
```bash
source ~/.zshrc
```
Preview what the installer would do without making changes:
```bash
./setup.sh --dry-run
```
Notes:
- If zsh is missing, the script autodetects your package manager and tries to install it (or honor `ZDOTS_PM`).
- You'll be offered to switch your default shell to zsh and to install the included Starship config.
- Logging: output is saved to `~/.cache/zdots-setup.log` (override path with `ZDOTS_LOGFILE`).
- In non-interactive environments (CI, containers), `chsh` and the immediate shell-switch are automatically skipped.

### Environment variables
| Variable | Purpose |
|----------|---------|
| `ZDOTS_YES=1` | Answer "yes" to all prompts |
| `ZDOTS_NO=1` | Answer "no" to all prompts |
| `ZDOTS_NONINTERACTIVE=1` | Use prompt defaults; skip `chsh` and shell-switch |
| `ZDOTS_PM=<name>` | Force a specific package manager (e.g. `apk`, `nix`, `xbps`) |
| `ZDOTS_MERGE=all\|yes\|no` | Control backup merge behavior |
| `ZDOTS_LOGFILE=<path>` | Override the setup log path |

## 🧩 VS Code Compatibility
To ensure full `.zshrc` sourcing and NVM support in VS Code, add this to your `settings.json`:

```json
"terminal.integrated.profiles.linux": {
  "zsh": {
    "path": "/bin/zsh",
    "args": ["-l"]
  }
},
"terminal.integrated.defaultProfile.linux": "zsh"
```
This launches Zsh as a login shell, ensuring all plugins, PATH logic, and NVM are properly initialized.

## ♻️ Backup merge flow
If a previous `~/.zshrc` is found, the installer asks once whether you want to merge content from it. If you opt in, you can merge per-category or choose "merge all." Categories:
- aliases
- exports
- PATH assignments
- functions

## 🧪 Performance
Shell startup time benchmark:
```bash
time zsh -i -c exit
# ~0.045s total
# Sample (hardware may vary):
# zsh -i -c exit  0.03s user 0.01s system 101% cpu 0.045 total
```
Test your setup by uncommenting the following: 
```bash
zmodload zsh/zprof
zprof
```
Use `zmodload zsh/zprof` and `zprof` to profile plugin load times.

## 📦 Recommended packages (not auto-installed)
These tools are commonly used with Zdots but aren't installed by the setup script:
```text
bat, eza, fzf, p7zip, starship, unrar, unzip, zoxide
```
Install them with your distro's package manager. Examples:
- Arch (pacman): `sudo pacman -S bat eza fzf p7zip starship unrar unzip zoxide`
- Debian/Ubuntu (apt): `sudo apt-get install bat eza fzf p7zip-full starship unrar unzip zoxide`
- Fedora (dnf): `sudo dnf install bat eza fzf p7zip p7zip-plugins starship unrar unzip zoxide`

## 🧰 Distro support
- Auto-detects: pacman, apt/apt-get, dnf, zypper, yum, apk, nix-env, xbps-install, emerge

Tested on recent Arch, Ubuntu, Fedora 42+, Alpine; other distros welcome via PRs.

## Uninstall
To revert to a previous backup:
```bash
mv ~/.zshrc ~/.zshrc.generated.bak
mv ~/.zshrc.bak.YYYYMMDDHHMM ~/.zshrc
```
Remove the repo if desired:
```bash
rm -rf ~/.zdots
```
## 🤝 Contributions
Feel free to fork, tweak, or submit pull requests.  
This setup is built for clarity, reproducibility, and performance — contributions that preserve those values are welcome.
