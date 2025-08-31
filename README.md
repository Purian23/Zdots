# Modular ZSH Dotfiles for Arch Linux

![Shell Benchmark](https://img.shields.io/badge/zsh%20startup%20time-230ms-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

A clean, reproducible Zsh setup designed for speed, system hygiene, and portability.  
Includes fzf-tab, zoxide, starship, and lazy-loaded NVM — optimized for Arch environments and terminal workflows.

## 🚀 Features
- Modular `.zshrc` with override support  
- fzf-tab fuzzy completions  
- zoxide smart directory jumping  
- Starship prompt  
- Lazy-loaded NVM with dynamic PATH  
- Arch-friendly aliases and install script  
- VS Code compatibility  
- Sub-250ms shell startup time  

## 🛠 Installation
Clone the repo and run the setup script:
```bash
git clone https://github.com/purian23/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```
Then reload your shell:
```bash
source ~/.zshrc
```
⚠️ If Zsh is not installed, the setup script will prompt you to install it and set it as your default shell.  
You can also install it manually via `sudo pacman -S zsh` and run `chsh -s $(which zsh)` to switch.

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

## 🧪 Performance
Shell startup time benchmark:
```bash
time zsh -i -c exit
# ~0.230s total
```
Use `zmodload zsh/zprof` and `zprof` to profile plugin load times.

## 🧼 Customization with `.zshrc.local`
This file is intentionally excluded from version control (`.gitignore`) and is meant for machine-specific overrides.

Use it to:
- Add personal aliases or functions  
- Set environment variables like `EDITOR`, `PATH`, or `STARSHIP_CONFIG`  
- Test plugins or completions without modifying core files  
- Keep secrets or tokens out of the public repo  

Example:
```zsh
export EDITOR=nvim
alias gs='git status'
```
## 📦 Packages Installed by `setup.sh`
```text
bat
eza
fzf
p7zip
starship
unrar
unzip
zoxide
```
## 🤝 Contributions
Feel free to fork, tweak, or submit pull requests.  
This setup is built for clarity, reproducibility, and performance — contributions that preserve those values are welcome.