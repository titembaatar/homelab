# 🏠 Homelab
A collection of scripts and configuration files for my homelab infrastructure. This repository contains everything needed to set up and maintain LXC containers for various services.

## 📚 Documentation
Detailed documentation is available in the [Wiki](../../wiki).

### Core Setup
- [🚀 LXC Setup](../../wiki/LXC-Setup) - Container creation and base configuration
- [📁 Samba Shares](../../wiki/Samba-Shares) - Network file sharing configuration
- [🔐 Caddy Proxy](../../wiki/Caddy-Proxy) - Reverse proxy for secure service access
- [🌐 Network Setup](../../wiki/Network-Setup) - Tailscale VPN and Pi-hole DNS

### Services & Applications
- [🐳 Docker Environment](../../wiki/Docker-Environment) - Container management system
- [📷 Immich Setup](../../wiki/Immich-Setup) - Self-hosted photo and video backup solution

### Maintenance & Security
- [💾 Backup Strategy](../../wiki/Backup-Strategy) - ZFS and LXC backup procedures

## 🚀 Quick Start Guide
### PVE license nag
To remove the proxmox popup at login, use [foundObjects/pve-nag-buster](https://github.com/foundObjects/pve-nag-buster/)

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

## 📜 Automation Scripts
### Container Management
- `scripts/add_container.sh` - Automates Docker container setup

### Proxy Configuration
- `scripts/caddy/install.sh` - Sets up Caddy reverse proxy
- `scripts/caddy/add_app.sh` - Adds applications to Caddy

### Network Setup
- `scripts/network/install.sh` - Configures Tailscale and Pi-hole

### LXC Helper Scripts
- `scripts/lxc_samba/lxc_cifs_share.sh` - Mount SMB/CIFS shares to LXC containers

### Backup Management
- `scripts/backups/zfs_backup.sh` - Manages ZFS snapshot backups

## 📋 Prerequisites
- Proxmox VE (tested with 8.x+)
- LXC containers with Fedora 41
- Basic knowledge of Linux administration
- Domain name with Cloudflare DNS (for Caddy)

## 🔄 Deployment Workflow
1. Create LXC containers in Proxmox
2. Configure basic SSH access using the quick start guide
3. Clone this repository
4. Run appropriate scripts for your needs
5. Refer to the [Wiki](../../wiki) for detailed configuration instructions
