# Homelab
## Prep a LXC

### Setting up SSH
On the LXC run :
```bash
sudo dnf up -y
sudo dnf install openssh-server -y
sudo systemctl enable --now sshd
sudo systemctl status sshd
useradd titem
passwd titem
usermod -aG wheel titem
```
On the main machine to ssh with ssh-key run :
```bash
# if no ssh key, generate one
ssh-keygen -t ed25519
```
```bash
# run from here if ssh key
ssh-copy-id -i ~/.ssh/id_ed25519.pub titem@<ip-adress>
```

### .dotfiles
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
zsh
clear
```

## \[LXC\] Samba Shares 
Install cockpit and plugins to LXC :
```bash
sudo dnf up -y
sudo dnf install curl -y
curl -sSL https://repo.45drives.com/setup | sudo bash
sudo dnf install cockpit cockpit-file-sharing cockpit-navigator cockpit-identities -y
sudo systemctl enable --now cockpit.socket
sudo systemctl status cockpit.socket
```

Setup smb server with:
```bash
sudo dnf install samba samba-common -y
sudo systemctl enable --now smb
sudo systemctl status smb
```

Visit cockpit GUI @`<ip-adress>:9090`, and login.  
If prompt to fix something, fix it.  
Go to `Identities`, create a `smb-share` group, then add groups `users, smb-share` to users.  
Don't forget to setup `Samba Password`.  
Go to `File Sharing` and add shares. `Edit permissions` to `775`, `titem:smb-share`. Toggle `Inherit Permissions` and `Windows ACLs with Linux/MacOS Support`.  
Then export `smb.conf` and copy/paste to `/etc/samba/smb.conf`  
You can check permissions of shares and subfolders in `File browser`.  

To mount samba shares to a machine, do the following :
  1. Create a `.smbcredentials` into `/root` :
```.smbcredentials
username=<user-name>
password=<password>
```
  2. Set permissions :
```bash
sudo chmod 600 ~/.smbcredentials
```

  3. Mount to fstab as follow for each shares :
```fstab
//<ip-adress>/<share-path> <mnt-point-path> cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775 0 0
```

## \[LXC\] docker
### Installation
Install [Docker](https://docs.docker.com/engine/install/fedora/) :
```bash
sudo dnf up -y
sudo dnf -y install dnf-plugins-core
sudo dnf-3 -y config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo systemctl status docker
```

### Docker user
Add user to docker group :
```bash
sudo usermod -aG docker titem
sudo newgrp docker
sudo newgrp docker
su titem
zsh
docker ps # to verify permissions
```

### Create proxy network
If the LXC should connect to proxy :
```bash
docker network create proxy
```

### Lazydocker
Run to install :
```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

If you want a `lzd alias` to run Lazydocker :
```bash
echo "alias lzd='lazydocker'" >> ~/.zshrc
source ~/.zshrc
```

## \[LXC\] Caddy
Follow the [LXC docker](#lxc-docker)  
Run the installation script [caddy/install.sh](./scripts/caddy/install.sh)  
Run the helper script [caddy/add_app.sh](./scripts/caddy/add_app.sh) to add a new application to the `Caddyfile`  

### Special cases
Proxmox/Synology need a different config in `Caddyfile`.  
You can run the helper script [caddy/add_app.sh](./scripts/caddy/add_app.sh) with the `--special-case` flag or add manually to the `Dockerfile` :
```
proxmox.mydomain.com {
  reverse_proxy https://<proxmox-ip>:8006 {
    transport http {
      tls_insecure_skip_verify
    }
  }
}
```

### From Docker hosts
To install and add a container to Caddyfile, run [add_container.sh](./scripts/add_container.sh)

## \[LXC\] Network
Before starting the LXC, add this to `/etc/pve/lxc/<lxc-id>.conf` :
```conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Then you can run the script `network/install.sh` or follow the next sections

### Installation
```bash
sudo dnf up -y
# Install tailscale
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install -y tailscale
sudo systemctl enable --now tailscaled
# Install pihole
curl -sSL https://install.pi-hole.net | bash
```

Then enable IP forwarding :
```bash
# Enable IP forwarding and make it permanant
sudo dnf install -y firewalld
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
sudo firewall-cmd --permanent --add-masquerade
```

Verify everything is running :
```bash
sudo systemctl status tailscaled
pihole status
```

Finally, start tailscale :
```bash
sudo tailscale up --advertise-exit-node --advertise-routes=10.0.0.0/24 --accept-dns=false
```

### UDP GRO forwarding (optional)
```bash
sudo dnf install -y ethtool
sudo ethtool -K eth0 rx-udp-gro-forwarding on
```

To make it persist across reboots, create `/etc/systemd/system/udp-gro-config.service` :
```conf
[Unit]
Description=Configure UDP GRO Forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -K eth0 rx-udp-gro-forwarding on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

And run :
```bash
sudo chmod 644 /etc/systemd/system/udp-gro-config.service
sudo systemctl daemon-reload
sudo systemctl enable --now udp-gro-config.service
sudo systemctl status udp-gro-config.service
```

### Tailscale setup
Visit the url to add the LXC to the tailscale network.
In the tailscale admin console, click on the `...` of the LXC and in the `Edit routes settings...` menu, validate the `subnet routes` and the `exit node`.  
Then go to `DNS` tab and add a nameserver with the tailscale IP of the LXC ( `tailscale ip -4` ). And check `Override local DNS`

### Pihole setup
Admin page to `<lxc-ip>/admin`, password displayed during installation.  
To generate a new password :
```bash
sudo pihole -a -p <new-password>
```

You can add more allowlists/blocklists in the admin panel under `Lists`.  
Recommended : [hagezi/dns-blocklists multi pro list](https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#pro).
Then you can run, to update pihole :
```bash
# Add additional blocklists to Pi-hole
sudo pihole -g
```
