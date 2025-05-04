# 💽 ZFS, NFS & SMB Server Setup (on mukhulai)
This document details the steps to configure ZFS datasets on the designated storage host (mukhulai, IP 10.0.0.10)
and set up NFS and SMB shares for access by Docker Swarm services and other network clients.

## ZFS Pool & Dataset Setup

### Create Independent Datasets
Create specific datasets for different types of data.
This isolates them and prevents accidental data loss if a parent dataset
(or linked VM/LXC if using Proxmox storage integration incorrectly) were deleted.
```bash
zfs create vault/juerbiesu   # Media storage
zfs create vault/khulan      # Databases
zfs create flash/yesugen     # Application config files
zfs create flash/yesui       # Docker compose/stack files & Git repo
zfs create flash/moge_khatun # Intended for Proxmox VM disk images
```

Verify creation:
```bash
zfs list -r vault
zfs list -r flash
```

### Set Dataset Properties
Set recommended ZFS properties.
* `recordsize=128k` (default) is generally good for mixed use, databases, configs, and VM disks.
* `recordsize=1M` is used for juerbiesu optimized for large media files.

```bash
# --- Pool-level settings ---
zfs set compression=lz4 vault flash
zfs set atime=off vault flash

# --- Dataset-specific settings ---
# Media Dataset
zfs set recordsize=1M vault/juerbiesu

# Other Datasets (Explicitly set to 128k or leave as default)
zfs set recordsize=128k vault/khulan
zfs set recordsize=128k flash/yesugen
zfs set recordsize=128k flash/yesui
zfs set recordsize=128k flash/moge_khatun # For VM disks
```

> [!INFO]
>
> The flash/moge_khatun dataset is intended for storing Proxmox VM disk images.
> It should be added as "ZFS" storage within the Proxmox Datacenter configuration and will not be shared via NFS/SMB in the steps below.

## User and Group Setup (on mukhulai)
Create a dedicated user and group for managing files and granting access via SMB.

```bash
groupadd user-share # Or choose a GID if needed, e.g., groupadd -g 1001 user-share
adduser titem     # Follow prompts to set password etc.
usermod -aG user-share,sudo titem # Add user to the share group and sudo
```

## Directory Permissions (on mukhulai)
Set ownership and permissions on the datasets that will be shared.
This allows user titem full access (e.g., via SMB) and prepares for NFS access mapped to UID/GID 1000 (via group permissions).
```bash
# Exclude moge_khatun as it's managed by Proxmox for VMs
chown -R titem:user-share /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesui
chmod -R 775 /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesui

# Set the setgid bit to ensure new files/dirs inherit the 'user-share' group
chmod g+s /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesui
```

> [!INFO]
>
> Permissions 775 give rwx to user titem, rwx to group user-share, and r-x to others.
> The NFS squashed user (1000:1000) will access via group permissions

## NFS Server Setup (on mukhulai)
This is the recommended method for Docker Swarm volumes due to better security integration (no plain text passwords needed for mounting).

Install NFS Server :
```bash
apt update && apt install nfs-kernel-server -y
```

Edit the NFS exports file in `/etc/exports`.
Add lines for each dataset to be shared via NFS.
Restrict access to your local subnet (10.0.0.0/24) and map all client users to UID/GID 1000 on the server.
```
/vault/juerbiesu   10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/vault/khulan      10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesugen     10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesui       10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

Apply the new exports configuration and enable NFS service:
```bash
exportfs -ra
systemctl enable --now nfs-kernel-server
systemctl status nfs-kernel-server
```

## Samba Server Setup (on mukhulai - Optional, for non-Docker clients)
Provides access for clients or for direct user access.
Not recommended for Docker volumes due to credential handling.

Install Samba:
```bash
apt update && apt install samba samba-common -y
```

Configure SambaBack up the original configuration:
```bash
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

Edit the configuration file `/etc/samba/smb.conf`:
```
[global]
    workgroup = WORKGROUP
    server string = Mukhulai File Server
    security = user
    map to guest = bad user
    log file = /var/log/samba/%m.log
    max log size = 50
    passdb backend = tdbsam
    # Optional Enhancements below - consider security implications
    # unix password sync = yes
    # vfs objects = acl_xattr
    # map acl inherit = yes
    # store dos attributes = yes

[juerbiesu]
    path = /vault/juerbiesu
    browseable = yes
    writable = yes
    create mask = 0664  # Files: rw-rw-r--
    directory mask = 0775 # Dirs: rwxrwxr-x
    valid users = @user-share # Only users in the 'user-share' group

[khulan]
    path = /vault/khulan
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @user-share

[yesugen]
    path = /flash/yesugen
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @user-share

[yesui]
    path = /flash/yesui
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @user-share
```

> [!INFO]
>
> moge_khatun is excluded as it's for VMs

Create Samba User PasswordSet a Samba password for your Linux user (titem).
This is separate from the Linux login password.
```bash
smbpasswd -a titem
systemctl enable --now smbd nmbd # smbd is file sharing, nmbd handles NetBIOS name resolution
systemctl status smbd nmbd
```

## Defining Docker NFS Volumes (for Stack Files)
This is how your Docker Swarm services will primarily access the NFS shares.
Define volumes in your docker-compose.yml stack file:
```yml
# Example docker-compose.yml snippet
version: '3.8'

services:
  some-service:
    image: ...
    volumes:
      - yesugen_config:/config # Mounts the Docker volume named 'yesugen_config'
      - khulan_db_data:/var/lib/database # Mounts the 'khulan_db_data' volume
    # ...

volumes:
  yesugen_config:
    driver: local
    driver_opts:
      type: nfs
      # Use mukhulai's IP (10.0.0.10). 'soft' can prevent hangs if NFS server is unreachable.
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime # Consider adding intr,timeo=,retrans=
      device: ":/flash/yesugen" # Path as exported ON THE NFS SERVER
  khulan_db_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/vault/khulan"
  yesui_compose:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/flash/yesui"
  juerbiesu_media:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/vault/juerbiesu"

# Remember: Swarm node VMs must have the 'nfs-common' package installed.
```

## Manual Client Mounting (Optional)
This section details how to manually mount the shares on other Linux client machines for direct access,
not typically needed for the Swarm nodes themselves if using Docker NFS volumes.

Install Client Utilities
```bash
sudo apt update # Or dnf update for Fedora
sudo apt install nfs-common cifs-utils -y # Or dnf install nfs-utils cifs-utils -y
sudo mkdir -p /mnt/{juerbiesu,khulan,yesugen,yesui}
```

Add to `/etc/fstab` for persistence:
```
# NFS Shares
# <Server IP>:<Export Path>  <Mount Point>          <Type> <Options>                              <Dump> <Pass>
10.0.0.10:/vault/juerbiesu   /mnt/homelab/juerbiesu nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/vault/khulan      /mnt/homelab/khulan    nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesugen     /mnt/homelab/yesugen   nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesui       /mnt/homelab/yesui     nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0

# Or SMB Shares
# //<Server IP>/<Share Name> <Mount Point>          <Type> <Options>                                                                     <Dump> <Pass>
//10.0.0.10/juerbiesu        /mnt/homelab/juerbiesu cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/khulan           /mnt/homelab/khulan    cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/yesugen          /mnt/homelab/yesugen   cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/yesui            /mnt/homelab/yesui     cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
```

> [!INFO]
>
> Adjust uid/gid in SMB mount options to match the local user you want to own the files on the client

For SMB do not forget to create `/root/.smbcreds`:
```
username=titem
password=YOUR_SAMBA_PASSWORD
```

```bash
sudo chmod 600 /root/.smbcreds
```

After editing `/etc/fstab`, mount all:
```bash
sudo mount -a
```
