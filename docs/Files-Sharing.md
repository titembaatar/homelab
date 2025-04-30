# 📁 Proxmox Host File Sharing Guide
This guide explains how to set up independent ZFS datasets and configure NFS/SMB file sharing directly on your Proxmox host.

## 📋 Overview
This guide covers:
1. Create an independent ZFS datasets
2. Setting up user and group permissions
3. Configuring NFS server on Proxmox
4. Configuring Samba server on Proxmox
5. Mounting shares on client machines

## 🚀 ZFS Dataset Setup
### Create an Independent Dataset
You can create as many datasets as you want. I prefer this approach because Proxmox won't link it to a LXC/VM.  
This allow to not delete all you data by deleting the wrong LXC/VM (yup, it _sadly_ happened...)
```bash
zfs create vault/data
zfs create vault/db
zfs create config/config
```

> I like to create a dataset for my media files `data`, for databases like immich `db` and `config` for my compose and config files.
> Plus, make it easy to setup backups on more targeted things (See [Backup Strategy](./Backup-Strategy))

Verify the creation was successful:
```bash
zfs list -r vault
zfs list -r config
```

### Set Dataset Properties
Set appropriate properties for the dataset:
```bash
# Set compression if not already enabled
zfs set compression=lz4 vault/data
# Disable atime to improve performance
zfs set atime=off vault/data
zfs set atime=off vault/db
zfs set atime=off config/config
# Set appropriate recordsize for general file sharing
zfs set recordsize=1M vault/data
zfs set recordsize=1M vault/db
zfs set recordsize=1M config/config
```

## 👥 User and Group Setup
### Create User and Group
Create a group for shared access and a user:
```bash
# Create the user-share group
groupadd -g 101000 user-share

# Create user if it doesn't exist
useradd -m titem
passwd titem

# Add titem to required groups
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
chown -R titem:user-share /vault/data /vault/db /config/config
chmod -R 775 /vault/data /vault/db /config/config

# Set the setgid bit to ensure new files inherit the group
chmod g+s /vault/data /vault/db /config/config
```

## 🌐 NFS Server Setup
### Install NFS Server
Install the necessary NFS server packages:
```bash
apt update
apt install nfs-kernel-server -y
```

### Configure Exports
Edit the NFS exports file to share your dataset:
```bash
# Open exports file
nvim /etc/exports
```

Add your export configuration:
```
/vault/data *(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

Or for more security, limit to your local network:
```
/vault/data 10.0.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
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

### Configure Firewall (optionnal)
If you have a firewall enabled, allow NFS traffic:
```bash
iptables -A INPUT -p tcp -s 10.0.0.0/24 --dport 2049 -j ACCEPT
iptables -A INPUT -p udp -s 10.0.0.0/24 --dport 2049 -j ACCEPT
```

## 📂 Samba (SMB) Server Setup
### Install Samba
Install Samba server packages:
```bash
apt update
apt install samba samba-common -y
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

[Data]
    path = /vault/data
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[DB]
    path = /vault/db
    browseable = yes
    writable = yes
    create mask = 0775
    directory mask = 0775
    valid users = @user-share

[Config]
    path = /config/config
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

### Configure Firewall for Samba (optionnal)
```bash
iptables -A INPUT -p tcp -s 10.0.0.0/24 --dport 139 -j ACCEPT
iptables -A INPUT -p tcp -s 10.0.0.0/24 --dport 445 -j ACCEPT
```

## 📱 Client Configuration
### Mounting NFS Shares on Linux
```bash
# Create mount directory
sudo mkdir -p /mnt/data

# Mount NFS share
sudo mount -t nfs <proxmox-ip>:/vault/data /mnt/data

# Add to fstab for persistence
echo "<proxmox-ip>:/vault/data /mnt/data nfs rw,defaults,_netdev 0 0" | sudo tee -a /etc/fstab
```

### Mounting SMB Shares on Linux
```bash
# Create mount directory
sudo mkdir -p /mnt/data-smb

# Install CIFS utilities
sudo apt install cifs-utils -y

# Create a credentials file
sudo nvim /root/.smbcredentials
```

Add the following content to the credentials file:
```
username=titem
password=your_password
```

Set secure permissions:
```bash
sudo chmod 600 /root/.smbcredentials
```

Mount the share:
```bash
sudo mount -t cifs //<proxmox-ip>/Data /mnt/data-smb -o credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775

# Add to fstab for persistence
echo "//<proxmox-ip>/Data /mnt/data-smb cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,dir_mode=0775,file_mode=0775,_netdev 0 0" | sudo tee -a /etc/fstab
```

> The `Data` correspond to the name set in the `smb.conf`, here `[Data]`

## 🛠️ Troubleshooting
### Common NFS Issues
1. **Permissions Issues**
   - Check the UID/GID mapping between server and client
   - Verify export options in `/etc/exports`
   - Check permissions on the dataset mountpoint

2. **Connection Refused**
   - Verify NFS service is running: `systemctl status nfs-kernel-server`
   - Check firewall settings
   - Try restarting the NFS server: `systemctl restart nfs-kernel-server`

3. **Performance Problems**
   - Adjust mount options like rsize/wsize in client fstab:
     ```
     <proxmox-ip>:/vault/data /mnt/proxmox-data nfs rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0
     ```

### Common Samba Issues
1. **Cannot Connect to Share**
   - Test connectivity with `smbclient -L <proxmox-ip> -U titem`
   - Verify Samba services are running: `systemctl status smbd nmbd`
   - Check firewall settings

2. **Permission Denied**
   - Verify user is in the correct group: `groups titem`
   - Check that user has a Samba password: `pdbedit -L`
   - Verify file permissions on the shared directory

## 📋 Maintenance Tasks
### Backing Up Samba Configuration
```bash
# Backup Samba configuration
cp /etc/samba/smb.conf /etc/samba/smb.conf.$(date +%Y%m%d)
```

### Monitoring Disk Usage
```bash
# Check disk usage
zfs list -o name,used,avail,refer,mountpoint vault/data
```

### Service Restart Commands
If you need to restart services after configuration changes:
```bash
# Restart NFS
systemctl restart nfs-kernel-server

# Restart Samba
systemctl restart smbd 
```
