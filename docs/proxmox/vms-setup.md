#  VMs Setup

## SSH Configuration
Debian update/upgrade and install SSH utils during OS installation.

### On the VM
Run these commands to create add user to sudo group:
```bash
su - root
apt-get install sudo
usermod -aG sudo titem
```

### From Your Client Machine
To enable password-less SSH access using key authentication:
```bash
# If you don't have an SSH key yet, generate one
ssh-keygen -t ed25519

# Copy your SSH key to the remote server
ssh-copy-id -i ~/.ssh/id_ed25519.pub titem@<ip-address>
```

## Dotfiles Configuration
Set up environment with:
```bash
sudo apt-get -y install git stow ninja-build gettext cmake curl build-essential unzip zsh
cd ~
mkdir -p ~/git
git clone https://github.com/titembaatar/.dotfiles.git
cd ~/.dotfiles
stow nvim ohmyposh zsh
cd ~/git
git clone https://github.com/neovim/neovim
cd neovim
git checkout stable
make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
curl -s https://ohmyposh.dev/install.sh | bash -s
chsh -s $(which zsh)
zsh
```

### What This Does
- Installs essential tools
- Clones dotfiles repository
- Uses GNU Stow to create symbolic links for:
  - Neovim configuration
  - Oh My Posh theme
  - ZSH shell configuration
- Clones neovim repository and build it
- Sets up Oh My Posh prompt
- Set ZSH shell as default
- Launches the ZSH shell

## Tips

### Edit GRUB for QuickSync passthrough
Configure `/etc/default/grub` and modify:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

### Install CIFS utils and NFS common
```bash
sudo apt-get install -y cifs-utils nfs-common
```

### Mounting NFS or SMB shares
Mount the shares in the `/etc/fstab` of the VM directly:
```
# SMB/CIFS
//<ip-address>/<smb-share> /<mount-name> cifs credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0

# NFS
<ip-address>:/<nfs-share>  /<mount-name> nfs  defaults,rw,noatime 0 0
```

For SMB/CIFS, create a `/root/.smbcreds` file:
```
username=<username>
password=<password>
```

### Backup Configuration
Make sure to include your VMs in your backup strategy as described in the [󰁯 Backup Strategy](./backup/strategy.md) guide.
