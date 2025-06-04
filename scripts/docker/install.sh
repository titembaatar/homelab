#!/usr/bin/env bash
# desc: Install Docker Engine and tools on Debian-based systems
set -e

username="${1:-titem}"

echo "Installing Docker Engine..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker "$username"

echo "Installing lazydocker..."
curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

user_home=$(getent passwd "$username" | cut -d: -f6)
user_bashrc="$user_home/.bashrc"

PATH_LINE="export PATH=\$HOME/.local/bin:\$PATH"
ALIAS_LINE="alias lzd=\"lazydocker\""

if ! grep -qF "$PATH_LINE" "$user_bashrc" 2>/dev/null; then
  echo "$PATH_LINE" >> "$user_bashrc"
fi

if ! grep -qF "$ALIAS_LINE" "$user_bashrc" 2>/dev/null; then
  echo "$ALIAS_LINE" >> "$user_bashrc"
fi

echo "Docker installation completed"
echo "User '$username' added to docker group"
echo "Lazydocker installed with alias 'lzd'"
echo "Log out and back in for group membership to take effect"
