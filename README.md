# Modular ZSH Dotfiles for Arch Linux (Zdots)

![Shell Benchmark](https://img.shields.io/badge/zsh%20startup%20time-230ms-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

A clean, reproducible Zsh setup designed for speed, system hygiene, and portability.  
Includes fzf-tab, zoxide, starship, and lazy-loaded NVM — optimized for Arch environments and terminal workflows.

## 🚀 Features
- Modular source files in `~/.zdots/zsh/` 
- fzf-tab fuzzy completions  
- zoxide smart directory jumping  
- Starship prompt  
- Lazy-loaded NVM with dynamic PATH  
- Alias and install script friendly
- VS Code compatibility  
- Sub-250ms shell startup time  
- Backs up your existing ~/.zshrc to ~/.zshrc.bak.TIMESTAMP
- Merges your aliases, exports, PATH changes, and functions from the backup into the new `.zshrc`
- Concatenates zdots’ modular files into a single .zshrc for speed

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
Test your setup by uncommenting the following: 
```bash
zmodload zsh/zprof
zprof
```
Use `zmodload zsh/zprof` and `zprof` to profile plugin load times.

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
## Uninstall
To revert to a previous backup:
```bash
mv ~/.zshrc ~/.zshrc.generated.bak
mv ~/.zshrc.bak.YYYYMMDDHHMMSS ~/.zshrc
```
Remove the repo if desired:
```bash
rm -rf ~/.zdots
```
## 🤝 Contributions
Feel free to fork, tweak, or submit pull requests.  
This setup is built for clarity, reproducibility, and performance — contributions that preserve those values are welcome.