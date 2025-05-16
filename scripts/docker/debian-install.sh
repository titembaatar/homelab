#!/usr/bin/env bash
set -e

# Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker titem

# Lazydocker
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

PATH_LINE="export PATH=\$HOME/.local/bin:\$PATH"
ALIAS_LINE="alias lzd=\"lazydocker\""

if ! grep -qF "$PATH_LINE" "$HOME"/.bashrc; then
  echo "$PATH_LINE" >> "$HOME"/.bashrc
fi

if ! grep -qF "$ALIAS_LINE" "$HOME"/.bashrc; then
  echo "$ALIAS_LINE" >> "$HOME"/.bashrc
fi


sudo su titem
