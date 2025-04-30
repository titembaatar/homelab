#  Proxmox ZFS Pools

##  ZFS Dataset Setup

### Create an Independent Dataset
You can create as many datasets as you want.
I prefer this approach because Proxmox won't link it to a LXC/VM.  
This allow to not delete all you data by deleting the wrong LXC/VM (yup, it _sadly_ happened...)
```bash
zfs create vault/juerbiesu   # media
zfs create vault/khulan      # databases
zfs create flash/yesugen     # config files
zfs create flash/yesui       # compose files
zfs create flash/moge_khatun # vms boot disks
```

Verify the creation was successful:
```bash
zfs list -r vault
zfs list -r flash
```

### Set Dataset Properties
Set appropriate properties for the pools, and by extend, to all datasets children:
```bash
zfs set compression=lz4 vault && \
zfs set atime=off vault && \
zfs set recordsize=1M vault
zfs set compression=lz4 flash && \
zfs set atime=off flash && \
zfs set recordsize=1M flash
```

##  User and Group Setup

### Create User and Group
Create a group for shared access and a user:
```bash
groupadd -g 101000 user-share
adduser titem
usermod -aG user-share,sudo titem
```

> We use a gid of `101000` for `user-share` because when pass to a LXC,
> Proxmox pass the shared directories with the `uid-100000:gid-100000` permissions
> Resulting in permissions of `1000:1000` on the LXC. You can then create a user/group
> with a uid and gid of 1000, then in Docker you can set `user: 1000:1000` to avoid
> any permissions issues.

### Set Directory Permissions
Set appropriate ownership and permissions on the zfs dataset:
```bash
chown -R titem:user-share /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesugen /flash/moge_khatun
chmod -R 775 /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesugen /flash/moge_khatun

# Set the setgid bit to ensure new files inherit the group
chmod g+s /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesugen /flash/moge_khatun
```

## 󰡰 NFS Server Setup

### Install NFS Server
Install the necessary NFS server packages:
```bash
apt update && apt install nfs-kernel-server -y
```

### Configure Exports
Edit the NFS exports file to share your dataset:
```bash
# Open exports file
nvim /etc/exports
```

Add your export configuration:
```
/vault/juerbiesu *(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

Or for more security, limit to your local network:
```
/vault/juerbiesu 10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

Apply the new exports configuration:
```bash
exportfs -ra
```

### Start and Enable NFS Service
```bash
systemctl enable --now nfs-kernel-server
systemctl status nfs-kernel-server
```

## 󰡰 Samba Server Setup

### Install Samba
Install Samba server packages:
```bash
apt update && apt install samba samba-common -y
```

### Configure Samba
Back up the original configuration:
```bash
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

Create a new configuration:
```bash
nvim /etc/samba/smb.conf
```

Add the following configuration:
```ini
[global]
    workgroup = WORKGROUP
    server string = Proxmox File Server
    security = user
    map to guest = bad user
    log file = /var/log/samba/%m.log
    max log size = 50
    passdb backend = tdbsam
    unix password sync = yes
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

[Juerbiesu]
    path = /vault/juerbiesu
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[Khulan]
    path = /vault/khulan
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[Yesugen]
    path = /flash/yesugen
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[Yesui]
    path = /flash/yesui
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[Mogekhatun]
    path = /flash/moge_khatun
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share
```

### Create Samba User
Add your user to Samba's user database:
```bash
# Add titem user to Samba
smbpasswd -a titem
```

### Start and Enable Samba Service
```bash
systemctl enable --now smbd
systemctl status smbd
```

## 󱩛 Client Configuration

### Mounting NFS Shares on Linux
```bash
# Create mount directory
sudo mkdir -p /mnt/{juerbiesu,khulan,yesugen,yesui,moge_khatun}
```

Add to `/etc/fstab` for persistence:
```
<proxmox-ip>:/vault/juerbiesu   /mnt/juerbiesu   nfs rw,defaults,_netdev 0 0
<proxmox-ip>:/vault/khutan      /mnt/khutan      nfs rw,defaults,_netdev 0 0
<proxmox-ip>:/flash/yesugen     /mnt/yesugen     nfs rw,defaults,_netdev 0 0
<proxmox-ip>:/flash/yesui       /mnt/yesui       nfs rw,defaults,_netdev 0 0
<proxmox-ip>:/flash/moge_khatun /mnt/moge_khatun nfs rw,defaults,_netdev 0 0
```

### Mounting SMB Shares on Linux
```bash
# Create mount directory
sudo mkdir -p /mnt/{juerbiesu,khutan,yesugen,yesui,moge_khatun}

# Install CIFS utilities
sudo apt install cifs-utils -y

# Create a credentials file
sudo nvim /root/.smbcreds
```

Add the following content to the credentials file:
```
username=titem
password=your_password
```

Set secure permissions:
```bash
sudo chmod 600 /root/.smbcreds
```

Add to `/etc/fstab` for persistence:
```
//<proxmox-ip>/Juerbiesu   /mnt/juerbiesu   cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0
//<proxmox-ip>/Khutan      /mnt/khutan      cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0
//<proxmox-ip>/Yesugen     /mnt/yesugen     cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0
//<proxmox-ip>/Yesui       /mnt/yesui       cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0
//<proxmox-ip>/Mogekhatun  /mnt/moge_khatun cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0
```

