# 🏠 Homelab
A collection of scripts and configuration files for my homelab infrastructure. This repository contains everything needed to set up and maintain LXC containers for various services.

## 📚 Documentation
Detailed documentation is available in the [Wiki](../../wiki).

## 🚀 Quick Start Guide
### LXC Container Setup
Set up a new LXC container with:
```bash
# Install SSH
sudo dnf up -y
sudo dnf install openssh-server -y
sudo systemctl enable --now sshd
useradd titem
passwd titem
usermod -aG wheel titem

# Set up SSH key authentication from your main machine
ssh-copy-id -i ~/.ssh/id_ed25519.pub titem@<container-ip>
```

### Available Configurations
This repo includes setup instructions and automation scripts for:

- **📁 Samba File Sharing** - Network storage
- **🐳 Docker Environment** - Container management
- **🔐 Caddy Reverse Proxy** - Secure access to services
- **🌐 Network (Tailscale & Pi-hole)** - VPN and DNS
- **💾 Backup Strategy** - LXC and ZFS backups

## 📜 Scripts
### Container Management
- `scripts/add_container.sh` - Automates Docker container setup

### Proxy Configuration
- `scripts/caddy/install.sh` - Sets up Caddy reverse proxy
- `scripts/caddy/add_app.sh` - Adds applications to Caddy

### Network Setup
- `scripts/network/install.sh` - Configures Tailscale and Pi-hole

### Backup Management
- `scripts/backups/zfs_backup.sh` - Manages ZFS snapshot backups

## 📋 Prerequisites
- Proxmox VE (tested with 8.x+)
- LXC containers with Fedora 41
- Basic knowledge of Linux administration
- Domain name with Cloudflare DNS (for Caddy)

## 🔄 Usage Flow
1. Create LXC containers in Proxmox
2. Configure basic SSH access
3. Clone this repository
4. Run appropriate scripts for your needs
5. Refer to the [Wiki](../../wiki) for detailed configuration instructions
