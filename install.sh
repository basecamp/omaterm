#!/usr/bin/env bash
set -euo pipefail

echo
echo -e " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                   ███    ███                "

# ─────────────────────────────────────────────
# Install all packages
# ─────────────────────────────────────────────
OFFICIAL_PKGS=(
  # Base tools
  base-devel git openssh sudo less inetutils whois

  # Shell & terminal
  starship fzf eza zoxide tmux btop jq gum tldr

  # Editors & dev tools
  neovim luarocks clang llvm rust mise github-cli lazygit lazydocker opencode

  # Docker
  docker docker-buildx docker-compose

  # Media & image processing
  ffmpeg imagemagick libheif libvips libyaml openslide poppler-glib mupdf-tools rav1e svt-av1

  # Networking
  tailscale
)

echo
echo "==> Installing Arch packages..."
sudo pacman -Syu --needed --noconfirm "${OFFICIAL_PKGS[@]}"

if ! command -v yay &>/dev/null; then
  echo
  echo "==> Installing yay..."
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

AUR_PKGS=(
  claude-code
)

echo
echo "==> Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ─────────────────────────────────────────────
# Git config
# ─────────────────────────────────────────────
echo
echo "==> Configuring git..."

# Get user info via gum (only if not already set)
GIT_NAME=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  echo
  if [ -z "$GIT_NAME" ]; then
    GIT_NAME=$(gum input --placeholder "Your full name" --prompt "Git user name: " </dev/tty)
  fi
  if [ -z "$GIT_EMAIL" ]; then
    GIT_EMAIL=$(gum input --placeholder "your@email.com" --prompt "Git email: " </dev/tty)
  fi
fi

cat >"$HOME/.gitconfig" <<GITCONFIG
[user]
	name = ${GIT_NAME}
	email = ${GIT_EMAIL}

[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential

[alias]
	co = checkout
	br = branch
	ci = commit
	st = status
[init]
	defaultBranch = master
[pull]
	rebase = true
[push]
	autoSetupRemote = true
[diff]
	algorithm = histogram
	colorMoved = plain
	mnemonicPrefix = true
[commit]
	verbose = true
[column]
	ui = auto
[branch]
	sort = -committerdate
[tag]
	sort = -version:refname
[rerere]
	enabled = true
	autoupdate = true
GITCONFIG

# ─────────────────────────────────────────────
# Shell config
# ─────────────────────────────────────────────
echo
echo "==> Writing ~/.bashrc..."
cat >"$HOME/.bashrc" <<'BASHRC'
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export EDITOR="nvim"
export PATH="$PATH:./bin"

# File system
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

alias cd="zd"
zd() {
  if [ $# -eq 0 ]; then
    builtin cd ~ && return
  elif [ -d "$1" ]; then
    builtin cd "$1"
  else
    z "$@" && printf "-> " && pwd || echo "Error: Directory not found"
  fi
}

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias c='opencode'
alias cx='claude --permission-mode=plan --allow-dangerously-skip-permissions'
alias d='docker'
alias r='rails'
n() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }

# Git
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# Init
eval "$(mise activate bash)"
eval "$(starship init bash)"
eval "$(zoxide init bash)"
BASHRC

echo "==> Writing ~/.bash_profile..."
cat >"$HOME/.bash_profile" <<'BASHPROFILE'
[[ -f ~/.bashrc ]] && . ~/.bashrc
BASHPROFILE

echo "==> Writing starship config..."
mkdir -p "$HOME/.config"
cat >"$HOME/.config/starship.toml" <<'STARSHIP'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[>](bold red)"
success_symbol = "[>](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = ".../"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "+${count} "
diverged   = "+-${ahead_count}/${behind_count} "
behind     = "-${count} "
conflicted = "x "
up_to_date = ""
untracked  = "? "
modified   = "* "
stashed    = "$"
staged     = "+"
renamed    = "r"
deleted    = "d"
STARSHIP

echo
echo "==> Writing mise config..."
mkdir -p "$HOME/.config/mise"
cat >"$HOME/.config/mise/config.toml" <<'MISE'
[settings]
experimental = true
idiomatic_version_file_enable_tools = ["ruby"]
MISE

echo
echo "==> Setup LazyVim..."
git clone https://github.com/LazyVim/starter ~/.config/nvim

# ─────────────────────────────────────────────
# Enable systemd services
# ─────────────────────────────────────────────
echo
echo "==> Enabling services..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now sshd.service
sudo systemctl enable --now tailscaled.service

# Add user to docker group
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to docker group (re-login to take effect)"
fi

# ─────────────────────────────────────────────
# Interactive setup
# ─────────────────────────────────────────────
echo
if gum confirm "Authenticate with GitHub?" </dev/tty; then
  gh auth login
fi

echo
if gum confirm "Connect to Tailscale network?" </dev/tty; then
  sudo tailscale up --ssh --accept-routes
fi

# ─────────────────────────────────────────────
# Post-install steps
# ─────────────────────────────────────────────
echo
echo "==> Setup complete! Re-login for Docker setup to take effect."
