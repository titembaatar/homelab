# 💽 ZFS, NFS & SMB Server Setup
This document details the steps to configure NFS and SMB shares for existing ZFS datasets on the designated storage host (`mukhulai`, IP `10.0.0.10`) for access by Docker Swarm services and other network clients.

**Assumptions:**
* ZFS pools `vault` and `flash` already exist on `mukhulai`.
* The following datasets exist and contain the relevant data:
    * `vault/data` (Media)
    * `vault/db` (Databases)
    * `flash/yesugen` (Application config files)
    * `flash/yesui` (Docker compose/stack files & Git repo)
    * `flash/moge_khatun` (VMs disks install disks)

## Set Dataset Properties
Verify or set recommended ZFS properties on existing datasets.
`recordsize=128k` (default) is generally good for mixed use, databases, and configs.
`recordsize=1M` is often used for large media files.

```bash
zfs set compression=lz4 vault flash
zfs set atime=off vault flash
zfs set recordsize=1M vault/juerbiesu
zfs set recordsize=128k vault/khulan
zfs set recordsize=128k flash/yesugen
zfs set recordsize=128k flash/yesui
zfs set recordsize=128k flash/moge_khatun
```

## User and Group Setup
Ensure a dedicated user (`titem`) and group (`nfs-share`) exist for direct management and SMB access.
```bash
groupadd -g 2000 nfs-share || echo "Group nfs-share likely already exists"
getent group nfs-share
adduser titem
usermod -aG nfs-share,sudo titem
```

> [!NOTE]
>
> The GID for `nfs-share` (2000) is used for grouping in SMB.
> NFS access for Docker will be mapped differently via `all_squash` below.

## Directory Permissions
Verify or set ownership and permissions on the datasets that will be shared via NFS for Docker.
Ownership should match the `anonuid`/`anongid` used in the NFS share definition (`1000:1000`) to ensure containers running as UID/GID 1000 have correct access.
```bash
chown -R titem:1000 /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesui /flash/moge_khatun
chmod -R 775 /vault/juerbiesu /vault/khulan/flash/yesugen /flash/yesui /flash/moge_khatun
chmod g+s /vault/juerbiesu /vault/khulan /flash/yesugen /flash/yesui /flash/moge_khatun
```

## NFS Server Setup using `/etc/exports`
This section details configuring NFS shares manually via `/etc/exports`, 
which is necessary if the ZFS `sharenfs` property does not reliably apply client restrictions in your environment.

### Install NFS Server Daemons
```bash
apt update && apt install nfs-kernel-server -y
```

### Configure `/etc/exports`
```ini
/vault/juerbiesu   10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/vault/khulan      10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesugen     10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesui       10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/moge_khatun 10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

### Apply Exports and Restart Service
```bash
exportfs -ra
systemctl restart nfs-kernel-server
systemctl status nfs-kernel-server
# verify NFS Exports
showmount -e localhost
```

> [!NOTE]
>
> The `showmount` command should list the paths `/vault/juerbiesu`, `/vault/khulan`, `/flash/yesugen`, `/flash/yesui`, `/flash/moge_khatun` and the client spec `10.0.0.0/24`

## Samba Server Setup
Provides access for clients like Windows/macOS or for direct user access by user `titem`.

### Install Samba
```bash
apt update && sudo apt install samba samba-common -y
```

### Configure Samba
Back up the original configuration if modifying:
```bash
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%F)
```

Add/ensure the following configuration to `/etc/samba/smb.conf`:
```ini
[global]
    workgroup = WORKGROUP
    server string = Mukhulai File Server
    security = user
    map to guest = bad user
    log file = /var/log/samba/%m.log
    max log size = 50
    passdb backend = tdbsam

[juerbiesu]
    path = /vault/juerbiesu
    comment = Media Files (vault/juerbiesu)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share

[khulan]
    path = /vault/khulan
    comment = Databases (vault/khulan)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share

[yesugen]
    path = /flash/yesugen
    comment = Application Configs (flash/yesugen)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share

[yesui]
    path = /flash/yesui
    comment = Docker Compose Files / Git Repo (flash/yesui)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share

[moge_khatun]
    path = /flash/moge_khatun
    comment = VMs Disks / Git Repo (flash/moge_khatun)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share
```

### Create/Verify Samba User Password
Ensure your Linux user (`titem`) has a Samba password set.
```bash
smbpasswd -a titem
```

### Start and Enable Samba Service
```bash
systemctl enable --now smbd nmbd
systemctl status smbd nmbd
```

## Defining Docker NFS Volumes
This is how your Docker Swarm services will primarily access the NFS shares.
Define volumes in your `docker-compose.yml` stack file, using logical names for the volumes and pointing the `device:` to the **actual exported path** on the NFS server (`mukhulai`, `10.0.0.10`).
Containers using these volumes should ideally run with UID `1000` and GID `1000` (e.g., via `PUID`/`PGID` environment variables).
```yaml
# Example docker-compose.yml snippet
services:
  some-service-using-configs:
    image: ...
    # Ensure container runs as 1000:1000 if possible
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - app_configs:/config # Mounts Docker volume 'app_configs' to /config in container
    # ...

  some-service-using-db:
     image: ...
     environment:
       - PUID=1000
       - PGID=1000
     volumes:
       - app_database:/var/lib/database # Mounts Docker volume 'app_database'
     # ...

  some-service-using-compose-files: # e.g., a CI/CD runner?
     image: ...
     # user: "1000:1000" # Alternative way to set user
     volumes:
       - compose_files:/workspace/stacks
     # ...

  some-service-using-media: # e.g., Plex, Jellyfin
     image: ...
     environment:
       - PUID=1000
       - PGID=1000
     volumes:
       - media_files:/media
     # ...

volumes:
  # Logical Volume Name: app_configs
  app_configs:
    driver: local
    driver_opts:
      type: nfs
      # Use mukhulai's IP (10.0.0.10). 'soft' can prevent hangs if NFS server is unreachable.
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime # Consider adding intr,timeo=,retrans=
      device: ":/flash/yesugen"

  # Logical Volume Name: app_database
  app_database:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/vault/khulan"

  # Logical Volume Name: compose_files
  compose_files:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/config/yesui"

  # Logical Volume Name: media_files
  media_files:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/vault/juerbiesu"

# Remember: Swarm node VMs must have the 'nfs-common' package installed.
```

## Manual Client Mounting
This section details how to manually mount the shares on other Linux client machines (like `Chingis`) for direct access.
This is **not** needed for the Swarm nodes if using Docker NFS volumes.

### Install Client Utilities
```bash
sudo apt update # Or dnf update for Fedora
sudo apt install nfs-common cifs-utils -y # Or dnf install nfs-utils cifs-utils -y
```

### Create Mount Points (Using Logical Names)
```bash
sudo mkdir -p /mnt/juerbiesu/ /mnt/khulan/ /mnt/yesugen/ /mnt/yesui/
```

### Add to `/etc/fstab` for Persistence
**NFS Mounts (Recommended for Linux Clients):**
```fstab
# <Server IP>:<Export Path> <Mount Point>   <Type> <Options>                              <Dump> <Pass>
10.0.0.10:/vault/juerbiesu  /mnt/juerbiesu/ nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/vault/khulan     /mnt/khulan/    nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesugen    /mnt/yesugen/   nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesui      /mnt/yesui/     nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
```

**SMB Mounts:**
*First, create a credentials file securely:*
```bash
sudo nvim /root/.smbcreds
# username=titem
# password=YOUR_SAMBA_PASSWORD
sudo chmod 600 /root/.smbcreds
```

*Then add to `/etc/fstab`:*
```fstab
# //<Server IP>/<Share Name> <Mount Point>   <Type> <Options>                                                                     <Dump> <Pass>
//10.0.0.10/data             /mnt/juerbiesu/ cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/db               /mnt/khulan/    cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/yesugen          /mnt/yesugen/   cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
//10.0.0.10/yesui            /mnt/yesui/     cifs   credentials=/root/.smbcreds,uid=1000,gid=1000,dir_mode=0775,file_mode=0664,_netdev 0 0
```

> [!NOTE]
>
> Adjust `uid`/`gid` in SMB mount options to match the local user you want to own the files on the client

### Mount Manually
After editing fstab, mount all:
```bash
sudo mount -a
```
