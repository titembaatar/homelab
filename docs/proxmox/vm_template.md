# 🖥️ VM Template
The script automates the creation of a virtual machine (VM) in Proxmox VE using a Debian 12 cloud image.  
It configures the VM with cloud-init for user setup, SSH access, and networking, and optionally converts the VM to a template for cloning.  
The script is designed for use in a homelab environment, ensuring quick and consistent VM deployments.

## Prerequisites
* Proxmox VE: A running Proxmox node with qm and pvesm commands available.
* Storage: A storage pool configured with content images in `/etc/pve/storage.cfg`.
* Packages: Install whois for mkpasswd (used for password hashing): `apt install whois`
* SSH Key: An SSH public key (e.g., ~/.ssh/id_ed25519.pub) from your main machine, ready to paste during script execution.

## Usage
Customize Configuration (Optional):
Edit the script’s configuration variables (at the top) to match your environment:
```bash
VM_ID=9000                # Unique VM ID
VM_NAME="debian-template" # VM name
STORAGE="moge_khatun"     # Proxmox storage pool
MEMORY=4096               # Memory in MB
CORES=2                   # CPU cores
DISK_SIZE="16G"           # Disk size
BRIDGE="vmbr0"            # Network bridge
CLOUD_IMG_URL="..."       # Debian 12 cloud image URL
USER_NAME="titem"         # Default user
```

Modify the cloud-init section in the script to add packages (e.g., curl, git) or configure NFS mounts.

> [!WARNING]
>
> Cloud-Init Password Security
> The script uses a hashed password for the user, generated with mkpasswd.
> However, the cloud-init documentation includes an important warning about this feature:
> Please note: while the use of a hashed password is better than plain text, the use of this feature is not ideal. Also, using a high number of salting rounds will help, but it should not be relied upon.
> To highlight this risk, running John the Ripper against the example hash above, with a readily available wordlist, revealed the true password in 12 seconds on a i7-2620QM.
> In other words, this feature is a potential security risk and is provided for your convenience only. If you do not fully trust the medium over which your cloud-config will be transmitted, then you should not use this feature.
>
> Source: Cloud-init Documentation

