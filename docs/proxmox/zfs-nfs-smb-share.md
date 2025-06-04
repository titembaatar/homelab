# 💽 ZFS, NFS & SMB Server Setup
This document details the steps to configure NFS and SMB shares for existing ZFS datasets
on the designated storage host (`mukhulai`, IP `10.0.0.10`) for access by Docker Swarm services and other network clients.

## Current Dataset Structure
**Assumptions:**
* ZFS pools `vault` and `flash` already exist on `mukhulai`
* The following datasets exist and contain the relevant data:
    * `vault/juerbiesu` (Media storage)
    * `vault/khulan` (Database storage)
    * `vault/nfs` (House shared files)
    * `flash/yesugen` (Application config files)
    * `flash/yesui` (Docker compose/stack files & Git repo)
    * `flash/moge_khatun` (VM boot disks)

## ZFS Dataset Configuration
### Set Recommended Properties
```bash
zfs set compression=lz4 vault flash
zfs set atime=off vault flash
zfs set recordsize=1M vault/juerbiesu
zfs set recordsize=128k vault/khulan vault/nfs flash/yesugen flash/yesui flash/moge_khatun
```

## User and Group Setup
### Create Service Accounts
```bash
groupadd -g 2000 nfs-share || echo "Group nfs-share already exists"
getent group nfs-share
adduser titem
usermod -aG nfs-share,sudo titem
```

> [NOTE]
>
> GID 2000 for `nfs-share` is used for SMB grouping. NFS access uses `all_squash` mapping.


### Configure Directory Permissions
Set ownership and permissions for Docker container access (UID/GID 1000):
```bash
chown -R 1000:1000 /vault/juerbiesu /vault/khulan /vault/nfs /flash/yesugen /flash/yesui /flash/moge_khatun
chmod -R 775 /vault/juerbiesu /vault/khulan /vault/nfs /flash/yesugen /flash/yesui /flash/moge_khatun
chmod g+s /vault/juerbiesu /vault/khulan /vault/nfs /flash/yesugen /flash/yesui /flash/moge_khatun
```

## NFS Server Configuration
### Install NFS Server
```bash
apt update && apt install nfs-kernel-server -y
```

### Configure Exports (`/etc/exports`)
Configure NFS shares with proper access controls:
```ini
/vault/juerbiesu   10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/vault/khulan      10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/vault/nfs         10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesugen     10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/yesui       10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
/flash/moge_khatun 10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

### Apply Configuration and Start Service
```bash
exportfs -ra
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server
systemctl status nfs-kernel-server
showmount -e localhost
```

The output should show all configured exports with the `10.0.0.0/24` client specification.

## SMB/Samba Configuration
### Install Samba
```bash
apt update && apt install samba samba-common -y
```

### Configure Samba Shares
Back up existing configuration and create new setup:
```bash
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%F)
```

Add the following configuration to `/etc/samba/smb.conf`:
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

[nfs]
    path = /vault/nfs
    comment = House Shared Files (vault/nfs)
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
    comment = VM Disks / Templates (flash/moge_khatun)
    browseable = yes
    writable = yes
    create mask = 0664
    directory mask = 0775
    valid users = @nfs-share
```

### Configure Samba
Set up Samba password for your user and enable samba service:
```bash
smbpasswd -a titem
systemctl enable --now smbd nmbd
systemctl status smbd nmbd
```

## Client Access Configuration
### Linux Client Setup
For direct access from Linux clients like main workstation:
```bash
sudo dnf update && dnf install nfs-utils cifs-utils -y
sudo mkdir -p /mnt/{juerbiesu,khulan,nfs,yesugen,yesui,moge_khatun}
```

**NFS Mounts:**
```fstab
10.0.0.10:/vault/juerbiesu   /mnt/juerbiesu   nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/vault/khulan      /mnt/khulan      nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/vault/nfs         /mnt/nfs         nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesugen     /mnt/yesugen     nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesui       /mnt/yesui       nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/moge_khatun /mnt/moge_khatun nfs rw,defaults,soft,_netdev,noatime,nodiratime 0 0
```

And mount all shares:
```bash
sudo mount -a
```

## Security Considerations
### NFS Security
- Limit access to homelab subnet (`10.0.0.0/24`)
- Use `all_squash` to prevent privilege escalation
- Consider firewall rules for additional protection

### SMB Security
- Use strong Samba passwords
- Limit valid users to specific groups
- Regular security updates for Samba package

### ZFS Security
- Regular ZFS scrubs: `zfs scrub vault && zfs scrub flash`
- Monitor dataset usage: `zfs list -o space`
- Verify backup integrity via automated scripts
