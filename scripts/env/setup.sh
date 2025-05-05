#!/bin/bash
set -e

DOTFILES_REPO="https://github.com/titembaatar/.dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
NEOVIM_BRANCH="stable"
NEOVIM_INSTALL_PREFIX="/usr/local"
OHMYPOSH_INSTALL_DIR="/usr/local/bin"

PACKAGES=(
  curl
  wget
  gnupg
  apt-transport-https
  ca-certificates
  lsb-release
  nfs-common
  cifs-utils
  qemu-guest-agent
  htop
  git
  stow
  zsh
  unzip
  build-essential
  gettext
  cmake
  ninja-build
)

print_info() { echo "INFO: $1"; }
print_warning() { echo "WARN: $1"; }
print_error() { echo "ERROR: $1" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_prerequisites() {
  print_info "Checking prerequisites..."

  if ! sudo -v; then
    print_error "This script requires sudo privileges."
  fi

  print_info "Prerequisites met."
}

ensure_packages() {
  print_info "Checking and installing required system packages..."

  local packages_to_install=()
  local packages=("${PACKAGES[@]}")

  for pkg in "${packages[@]}"; do
    if [[ " ${PACKAGES[*]} " =~ ${pkg} ]] && ! command_exists "$pkg"; then
      if [[ "$pkg" == "build-essential" ]] && command_exists make; then
        continue
      fi
      packages_to_install+=("$pkg")
    fi
  done

  local unique_packages=()
  if [[ ${#packages_to_install[@]} -gt 0 ]]; then
    mapfile -t unique_packages < <(printf "%s\n" "${packages_to_install[@]}" | sort -u)
  fi

  if [ ${#unique_packages[@]} -gt 0 ]; then
    print_info "Updating package list..."
    sudo apt-get update
    print_info "Installing missing packages: ${unique_packages[*]}"
    sudo apt-get install -y "${unique_packages[@]}"
  else
    print_info "All required packages installed."
  fi
}

setup_dotfiles() {
  print_info "Setting up dotfiles..."

  if [ -d "$DOTFILES_DIR" ]; then
    print_warning "Dotfiles directory '$DOTFILES_DIR' already exists. Skipping clone."
    print_info "Pulling latest changes..."
    (cd "$DOTFILES_DIR" && git pull origin main) || print_warning "Failed to pull dotfiles updates."
  else
    print_info "Cloning dotfiles from $DOTFILES_REPO to $DOTFILES_DIR..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  print_info "Stowing dotfiles from $DOTFILES_DIR..."
  if ! command_exists stow; then
    print_error "Stow command not found, but should have been installed. Check package installation."
  fi
  cd "$DOTFILES_DIR"
  stow nvim ohmyposh zsh

  cd "$HOME"

  print_info "Dotfiles setup complete."
}

setup_ohmyposh() {
  print_info "Setting up Oh My Posh..."
  if command_exists oh-my-posh; then
    print_info "Oh My Posh is already installed."
    return 0
  fi

  print_info "Installing Oh My Posh to $OHMYPOSH_INSTALL_DIR..."
  if ! sudo curl -L https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -o "$OHMYPOSH_INSTALL_DIR/oh-my-posh"; then
    print_error "Failed to download Oh My Posh."
  fi

  if ! sudo chmod +x "$OHMYPOSH_INSTALL_DIR/oh-my-posh"; then
    print_error "Failed to make Oh My Posh executable."
  fi

  print_info "Oh My Posh installed successfully."
}

build_neovim() {
  print_info "Setting up Neovim (building from source)..."

  local nvim_binary="$NEOVIM_INSTALL_PREFIX/bin/nvim"

  if command_exists nvim && [[ -x "$nvim_binary" ]] && "$nvim_binary" --version &>/dev/null; then
    print_info "Neovim seems to be installed at $nvim_binary. Skipping build."
    return 0
  fi

  print_info "Neovim not found or requires building. Starting build process..."

  local build_dir
  build_dir=$(mktemp -d)

  print_info "Using temporary build directory: $build_dir"

  print_info "Cloning Neovim repository (branch: $NEOVIM_BRANCH)..."

  if ! git clone --depth 1 --branch "$NEOVIM_BRANCH" https://github.com/neovim/neovim.git "$build_dir"; then
    print_error "Failed to clone Neovim repository."
  fi

  cd "$build_dir"

  print_info "Building Neovim..."
  if ! make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$NEOVIM_INSTALL_PREFIX"; then
    print_error "Failed to build Neovim. Check build dependencies and logs."
  fi

  print_info "Installing Neovim to $NEOVIM_INSTALL_PREFIX..."
  if ! sudo make install; then
    print_error "Failed to install Neovim."
  fi

  print_info "Cleaning up Neovim build directory..."

  cd "$HOME"
  rm -rf "$build_dir"

  print_info "Neovim ($NEOVIM_BRANCH) built and installed successfully to $nvim_binary"
}

set_default_shell() {
  print_info "Setting default shell to Zsh..."
  local current_shell
  current_shell=$(basename "$SHELL")

  if [ "$current_shell" == "zsh" ]; then
    print_info "Default shell is already Zsh."
    return 0
  fi

  if ! command_exists zsh; then
    print_warning "Zsh command not found. Cannot set as default shell."
    return 1
  fi

  local zsh_path
  zsh_path=$(command -v zsh)
  if [ -z "$zsh_path" ]; then
    print_warning "Could not find zsh executable path. Cannot change shell automatically."
    return 1
  fi

  if ! command_exists chsh; then
    print_warning "'chsh' command not found. Cannot change default shell automatically."
    print_warning "Please run 'sudo chsh -s $zsh_path $USER' manually."
    return 1
  fi

  print_info "Attempting to change default shell to Zsh for user $USER."
  if ! sudo chsh -s "$zsh_path" "$USER"; then
    print_warning "Failed to automatically change shell via chsh."
    print_warning "This might require interactive password entry or specific permissions."
    print_warning "Run 'sudo chsh -s $zsh_path $USER' manually if needed."
    return 1
  fi

  print_info "Default shell changed to Zsh. Changes will take effect on next login."
}

main() {
  check_prerequisites
  ensure_packages
  setup_dotfiles
  setup_ohmyposh
  build_neovim
  set_default_shell

  print_info "--- Environment Setup Complete! ---"
  print_info "Log out and log back in or start a new zsh session for all changes to take effect."
}

main

