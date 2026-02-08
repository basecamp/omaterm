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
# Install packages
# ─────────────────────────────────────────────
download() {
  curl -fsSL "https://raw.githubusercontent.com/basecamp/omaterm/master/$1"
}

section() {
  echo
  echo "==> $1"
  echo
}

OFFICIAL_PKGS=(
  base-devel git openssh sudo less inetutils whois
  starship fzf eza zoxide tmux btop jq gum tldr
  vim neovim luarocks clang llvm rust mise github-cli lazygit lazydocker opencode libyaml
  docker docker-buildx docker-compose
  tailscale
)

AUR_PKGS=(
  claude-code
)

section "Installing Arch packages..."
sudo pacman -Syu --needed --noconfirm "${OFFICIAL_PKGS[@]}"

if ! command -v yay &>/dev/null; then
  section "Installing yay..."
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

section "Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ─────────────────────────────────────────────
# Git config
# ─────────────────────────────────────────────
if [[ ! -f $HOME/.gitconfig ]]; then
  section "Configuring git..."

  GIT_NAME=$(gum input --placeholder "Your full name" --prompt "Git name: " </dev/tty)
  GIT_EMAIL=$(gum input --placeholder "your@email.com" --prompt "Git email: " </dev/tty)

  download config/gitconfig | sed "s/{{GIT_NAME}}/${GIT_NAME}/g; s/{{GIT_EMAIL}}/${GIT_EMAIL}/g" >"$HOME/.gitconfig"
fi

# ─────────────────────────────────────────────
# Shell config
# ─────────────────────────────────────────────
section "Writing configs..."
download config/bashrc >"$HOME/.bashrc"
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >"$HOME/.bash_profile"

# Starship (https://starship.rs/)
mkdir -p "$HOME/.config"
download config/starship.toml >"$HOME/.config/starship.toml"

# Mise (https://mise.jdx.dev/)
mkdir -p "$HOME/.config/mise"
download config/mise.toml >"$HOME/.config/mise/config.toml"

# LazyVim (https://www.lazyvim.org/)
if [[ ! -d $HOME/.config/nvim ]]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# ─────────────────────────────────────────────
# Bins
# ─────────────────────────────────────────────
section "Adding commands..."
mkdir -p .local/bin
download bin/omaterm-use-ssh-key >"$HOME/.local/bin/omaterm-use-ssh-key"
chmod +x "$HOME/.local/bin/omaterm-use-ssh-key"

# ─────────────────────────────────────────────
# Mise tooling
# ─────────────────────────────────────────────

section "Installing Ruby + Node..."
mise use -g node
mise use -g ruby

# ─────────────────────────────────────────────
# Enable systemd services
# ─────────────────────────────────────────────
section "Enabling services..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now sshd.service
sudo systemctl enable --now tailscaled.service

# Enable serial console in Proxmox VMs (for xterm.js console access)
if [[ -r /sys/class/dmi/id/sys_vendor ]] && grep -q "Proxmox" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
  sudo systemctl enable --now serial-getty@ttyS0.service
  echo "Enabled serial access for xterm.js consoles (remember to add serial port via Hardware > Add > Serial Port)"
fi

# ─────────────────────────────────────────────
# Setup Docker group to allow sudo-less access
# ─────────────────────────────────────────────
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
fi

# ─────────────────────────────────────────────
# Interactive setup
# ─────────────────────────────────────────────
echo
if gum confirm "Authenticate with GitHub?" </dev/tty; then
  gh auth login
fi

if gum confirm "Connect to Tailscale network?" </dev/tty; then
  echo "This might take a minute..."
  sudo tailscale up --ssh --accept-routes
fi

# ─────────────────────────────────────────────
# Post-install steps
# ─────────────────────────────────────────────
section "Setup complete!"
echo "You must log out once to make sudoless Docker available."
echo "Run omaterm-use-ssh-keys on a console with clipboard access to configure SSH keys"
