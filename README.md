# Omaterm

A minimal Omarchy-style single-file terminal setup for your headless Arch Linux server or dev box.

## Requirements

- Base Arch Linux installation
- Internet connection
- `sudo` privileges

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/basecamp/omaterm/master/install.sh | bash
```
```

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, github-cli, lazygit, lazydocker
- **System**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases
- **Media**: ffmpeg, imagemagick, poppler

## Interactive prompts

During installation you'll be asked for:
- Git user name
- Git email address
