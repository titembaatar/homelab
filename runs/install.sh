#!/usr/bin/env bash
set -e

HOMELAB_ROOT="$HOME/projects/homelab/"
LOCAL_BIN="$HOME/.local/bin"

echo -e "Installing Homelab Runner..."

mkdir -p "$LOCAL_BIN"

ln -sf "$HOMELAB_ROOT/runs/homelab" "$LOCAL_BIN/homelab"
chmod +x "$LOCAL_BIN/homelab"
source "$HOME"/.zshrc

echo -e "Homelab runner installed to $LOCAL_BIN/homelab"

if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "Warning: ~/.local/bin is not in your PATH"
    echo -e "Run: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && rzsh"
fi
