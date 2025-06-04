#!/usr/bin/env bash
set -e

homelab_dir="$HOME/projects/homelab/"
local_bin="$HOME/.local/bin"

mkdir -p "$local_bin"
ln -sf "$homelab_dir/runs/homelab" "$local_bin/homelab"
chmod +x "$local_bin/homelab"
source $HOME/.zshrc

if [[ ":$PATH:" != *":$local_bin:"* ]]; then
  echo -e "Warning: ~/.local/bin is not in your PATH"
fi
