#!/usr/bin/env bash
set -euo pipefail

echo
echo " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄████████    ▄████████   ▄▄▄▄███▄▄▄▄  
███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███    ███   ███    ███ ▄██▀▀▀███▀▀▀██▄
███    ███ ███   ███   ███   ███    ███    ▀███▀▀██   ███    █▀    ███    ███ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███   ▀  ▄███▄▄▄      ▄███▄▄▄▄██▀ ███   ███   ███
███    ███ ███   ███   ███ ▀███████████     ███     ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    █▄  ▀███████████ ███   ███   ███
███    ███ ███   ███   ███   ███    ███     ███       ███    ███   ███    ███ ███   ███   ███
 ▀██████▀   ▀█   ███   █▀    ███    █▀     ▄████▀     ██████████   ███    ███  ▀█   ███   █▀ 
                                                                   ███    ███                "

section() {
  echo -e "\n==> $1"
}

# ─────────────────────────────────────────────
# Install packages
# ─────────────────────────────────────────────
OFFICIAL_PKGS=(
  base-devel git openssh sudo less inetutils whois
  starship fzf eza zoxide tmux btop jq gum man-db tldr
  vim neovim luarocks
  clang llvm rust mise libyaml
  github-cli lazygit lazydocker opencode
  docker docker-buildx docker-compose
  tailscale
  chromium
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
# Omadots
# ─────────────────────────────────────────────
curl -fsSL https://install.omacom.io/dots | bash

section "Configuring bash..."
cat >>"$HOME/.bashrc" <<'EOF'
source ~/.config/shell/all
[[ -z $TMUX ]] && t
EOF
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >"$HOME/.bash_profile"

# ─────────────────────────────────────────────
# Omaterm configs and bins
# ─────────────────────────────────────────────
REPO="https://github.com/omacom-io/omaterm.git"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

section "Cloning Omaterm..."
git clone --depth 1 "$REPO" "$TMPDIR"

section "Installing config and bin..."
mkdir -p "$HOME/.config"
cp -Rf "$TMPDIR/config/"* "$HOME/.config/"
cp -Rf "$TMPDIR/bin/"* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/*"

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
echo "✓ Docker"

sudo systemctl enable --now sshd.service
echo "✓ sshd"

# ─────────────────────────────────────────────
# Setup Docker group to allow sudo-less access
# ─────────────────────────────────────────────
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "You must log out once to make sudoless Docker available."
fi

# ─────────────────────────────────────────────
# Interactive setup
# ─────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  echo
  if gum confirm "Authenticate with GitHub?" </dev/tty; then
    gh auth login
  fi
fi

if ! tailscale status &>/dev/null; then
  echo
  if gum confirm "Connect to Tailscale network?" </dev/tty; then
    echo "This might take a minute..."
    sudo systemctl enable --now tailscaled.service
    sudo tailscale up --ssh --accept-routes
  fi
fi

# ─────────────────────────────────────────────
# Post-install steps
# ─────────────────────────────────────────────
echo
echo "✓ Setup complete!"
