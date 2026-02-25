# Agents

## Cursor Cloud specific instructions

### Project overview

Zdots is a modular Zsh dotfiles/shell-configuration project. There is no build system, no package manager lockfile, and no test framework. The "application" is `setup.sh`, a Bash script that assembles modular `.zsh` config fragments from `zsh/` into `~/.zshrc`, installs Zinit (plugin manager), and optionally copies `starship.toml`.

### Running setup.sh non-interactively

Use environment variables to avoid interactive prompts:

```bash
ZDOTS_YES=1 ZDOTS_MERGE=all bash setup.sh
```

**Gotcha:** `ZDOTS_YES=1` says "yes" to all prompts, including `chsh` (change default shell), which requires a password and hangs in non-interactive environments. To skip the shell-change and immediate-switch prompts, use `ZDOTS_NO=1` instead (says "no" to everything), or kill the process after it prints "Starship config installed" — the important work is already done by that point.

### Linting

```bash
shellcheck setup.sh
```

Only two info-level notices (SC1091, SC2015); no errors or warnings.

### Testing the generated config

```bash
zsh -c 'source ~/.zshrc; echo "ZSH_VERSION=$ZSH_VERSION"'
```

First run after setup downloads Zinit plugins from GitHub (takes ~15s). Subsequent runs are fast (~70ms).

### Startup benchmark

```bash
zsh -c 'time zsh -i -c exit'
```

### Key paths

| Path | Purpose |
|------|---------|
| `setup.sh` | Main installer script |
| `zsh/*.zsh` | Modular Zsh config fragments |
| `starship.toml` | Starship prompt config |
| `~/.zshrc` | Generated config (output of setup.sh) |
| `~/.local/share/zinit/` | Zinit home + downloaded plugins |
| `~/.config/starship.toml` | Installed Starship config |
| `~/.cache/zdots-setup.log` | Setup log |
