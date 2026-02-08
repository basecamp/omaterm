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
  curl -fsSL "https://raw.githubusercontent.com/basecamp/omaterm/master/config/$1"
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

  download gitconfig | sed "s/{{GIT_NAME}}/${GIT_NAME}/g; s/{{GIT_EMAIL}}/${GIT_EMAIL}/g" >"$HOME/.gitconfig"
fi

# ─────────────────────────────────────────────
# Shell config
# ─────────────────────────────────────────────
section "Writing configs..."
download bashrc >"$HOME/.bashrc"
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >"$HOME/.bash_profile"

# Starship (https://starship.rs/)
mkdir -p "$HOME/.config"
download starship.toml >"$HOME/.config/starship.toml"

# Mise (https://mise.jdx.dev/)
mkdir -p "$HOME/.config/mise"
download mise.toml >"$HOME/.config/mise/config.toml"

# LazyVim (https://www.lazyvim.org/)
if [[ ! -d $HOME/.config/nvim ]]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# ─────────────────────────────────────────────
# Enable systemd services
# ─────────────────────────────────────────────
section "Enabling services..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now sshd.service
sudo systemctl enable --now tailscaled.service

# ─────────────────────────────────────────────
# SSH setup
# ─────────────────────────────────────────────
SSH_KEYS_ADDED=false
if [[ ! -f $HOME/.ssh/authorized_keys ]] || [[ ! -s $HOME/.ssh/authorized_keys ]]; then
  echo
  if gum confirm "Add SSH public key(s) for remote access?" </dev/tty; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    echo "Paste your SSH public key(s) below (one per line, blank line when done):"
    SSH_KEYS=""
    while IFS= read -r line </dev/tty; do
      [[ -z $line ]] && break
      SSH_KEYS="${SSH_KEYS}${line}\n"
    done

    if [[ -n $SSH_KEYS ]]; then
      printf "%s" "$SSH_KEYS" >"$HOME/.ssh/authorized_keys"
      chmod 600 "$HOME/.ssh/authorized_keys"
      echo "SSH keys added to authorized_keys"
      SSH_KEYS_ADDED=true
    fi
  fi
fi

# Only disable password auth if we actually configured SSH keys
if [[ $SSH_KEYS_ADDED == true ]]; then
  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sudo systemctl restart sshd.service
  echo "SSH configured for key-based authentication only"
fi

# ─────────────────────────────────────────────
# Setup Docker group to allow sudo-less access
# ─────────────────────────────────────────────
DOCKER_GROUP_ADDED=false
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to docker group"
  DOCKER_GROUP_ADDED=true
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
  echo "This might take a minute..."
  sudo tailscale up --ssh --accept-routes
fi

# ─────────────────────────────────────────────
# Post-install steps
# ─────────────────────────────────────────────
if [[ $DOCKER_GROUP_ADDED == true ]]; then
  echo
  echo "NOTE: Sudoless Docker requires logging out once first."
fi

section "Setup complete!"
