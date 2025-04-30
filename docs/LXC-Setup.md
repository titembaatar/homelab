# 🚀 LXC Setup
This guide explains how to set up and configure Linux Containers (LXC) for your homelab environment.

## 🔑 SSH Configuration
Secure Shell (SSH) enables secure remote access to your containers. Here's how to set it up:

### On the LXC
Run these commands to install and configure SSH:
```bash
sudo dnf up -y
sudo dnf install openssh-server -y
sudo systemctl enable --now sshd
sudo systemctl status sshd
useradd titem
passwd titem
usermod -aG wheel titem
```

### From Your Client Machine
To enable password-less SSH access using key authentication:
```bash
# If you don't have an SSH key yet, generate one
ssh-keygen -t ed25519

# Copy your SSH key to the remote server
ssh-copy-id -i ~/.ssh/id_ed25519.pub titem@<ip-address>
```

## 📄 Dotfiles Configuration
Set up your development environment with these configuration files:
```bash
sudo dnf -y install git stow curl
cd ~
git clone "https://github.com/titembaatar/.dotfiles.git"
cd .dotfiles
stow nvim
stow ohmyposh
stow zsh
sudo dnf -y install neovim zsh unzip
curl -s https://ohmyposh.dev/install.sh | bash -s
chsh -s $(which zsh)
zsh
```

### What This Does
- Installs essential tools (git, stow, curl)
- Clones your dotfiles repository
- Uses GNU Stow to create symbolic links for:
  - Neovim configuration
  - Oh My Posh theme
  - ZSH shell configuration
- Installs the required applications
- Sets up Oh My Posh prompt
- Set ZSH shell as default
- Launches the ZSH shell

## 📋 Additional LXC Types
Different LXC types require specific configurations:
- For **Files Sharing**: See [Files Sharing](./Files-Sharing.md)
- For **Caddy Reverse Proxy**: See [Caddy Proxy](./Caddy-Proxy)
- For **Network/DNS**: See [Network Setup](./Network-Setup)
- For **Docker Containers**: See [Docker Environment](./Docker-Environment)
- For **Immich Photo**: See [Immich Setup](./Immich-Setup)

## ⚙️ LXC Configuration Tips
### Resource Allocation
When creating a new LXC in Proxmox:
- Assign appropriate CPU cores based on workload (1-2 for light services, 2-4 for databases)
- Allocate sufficient RAM (1024 minimum, 2-4GB for most services)
- Create a reasonably sized root disk (8-16GB)

### Mounting Storage
For mounting external ZFS datasets to LXCs if the LXC is on the Proxmox node that hosts the ZFS datasets:
  * Configure `/etc/pve/lxc/<lxc-id>.conf` and add the ZFS datasets:
```conf
mp0: /vault/data,mp=/data,size=15000G
mp1: /config/config,mp=/config,backup=1,size=256G
```

### Mounting NFS or SMB shares
Mount the shares in the `/etc/fstab` of the Proxmox node, more info in the [Files Sharing section](./Files-Sharing).  
Then you just need to edit `/etc/pve/lxc/<lxc-id>.conf` and add:
```conf
mp0: /mnt/data,mp=/data,size=15000G
mp1: /mnt/config,mp=/config,backup=1,size=256G
```

### Networking
- Use DHCP for dynamic IP assignment
- For static IPs, edit the container configuration, or configure IP assignment via your router/DHCP handler.
- For a container that needs to act as a network device, add to `/etc/pve/lxc/<lxc-id>.conf`:
  ```
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
  ```

### Backup Configuration
Make sure to include your LXCs in your backup strategy as described in the [Backup Strategy](./Backup-Strategy) guide.
