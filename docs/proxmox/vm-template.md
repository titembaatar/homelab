# 🖥️ VM Template
The VM template system provides automated creation and cloning of virtual machines in Proxmox VE using Debian 12 cloud images.
It consists of two main scripts that work together to streamline VM deployment.

## Prerequisites
**On Proxmox Host:**
* Proxmox VE with `qm` and `pvesm` commands available
* Storage pool configured for images in `/etc/pve/storage.cfg`
* Package: `apt install whois` (for password hashing)
* Package: `apt install yq` (for YAML parsing in backup scripts)

**SSH Key Requirements:**
* SSH public key from main machine (e.g., `~/.ssh/chingis.pub`)
* The script will automatically generate a `mukhulai` SSH key pair if it doesn't exist

## Template Creation
### Default Configuration
The template script uses these default settings:
```bash
vm_id=9000                # Template VM ID
vm_name="debian-template" # Template name
vm_memory=4096            # Memory in MB
vm_cores=2                # CPU cores
vm_disk_size="16G"        # Disk size
vm_net_bridge="vmbr0"     # Network bridge
vm_storage="moge_khatun"  # Proxmox storage pool
username="titem"          # Default user
```

### Usage
```bash
# Basic usage (uses defaults)
homelab mukhulai scripts/proxmox/vm_template.sh

# Custom configuration
homelab mukhulai scripts/proxmox/vm_template.sh -i 9001 -n "custom-name" -u "myuser"

# Options
-i, --vm-id ID          VM ID (default: 9000)
-n, --name NAME         VM name (default: debian-template)
-u, --user USER         Default user (default: titem)
-k, --ssh-key PATH      Path to main machine SSH public key
```

## VM Cloning and Deployment
### Basic Cloning
```bash
# Clone VM with automatic configuration
homelab mukhulai scripts/proxmox/vm_clone.sh <vm_id> <hostname> [target_node]

# Examples
homelab mukhulai scripts/proxmox/vm_clone.sh 120 gateway borokhul
homelab mukhulai scripts/proxmox/vm_clone.sh 121 servarr borchi
homelab mukhulai scripts/proxmox/vm_clone.sh 122 ger mukhulai
```

## Automated Deployment Integration
### Complete Stack Deployment
The template and cloning system integrates with the automated deployment scripts:
```bash
runs/gateway        # Creates gateway VM + deploys services
runs/servarr <args> # Creates servarr VM + deploys services
runs/ger <args>     # Creates ger VM + deploys services
```

## Security Considerations
### SSH Key Management
* **Main Machine Key**: Provides access from your workstation
* **Mukhulai Key**: Enables automation and inter-VM communication
* **Key Storage**: Keys are embedded in cloud-init during template creation

### Cloud-Init Password Warning
The cloud-init system uses hashed passwords, but as noted in the cloud-init documentation:
> While the use of a hashed password is better than plain text, the use of this feature is not ideal...
> this feature is a potential security risk and is provided for your convenience only.

**Recommendation**: Rely on SSH key authentication and disable password authentication after initial setup.

## Storage Organization
### Template Storage Structure
```
/mnt/pve/moge_khatun/
├── template/
│   └── iso/
│       └── debian-12-genericcloud-amd64.iso
└── snippets/
    └── userconfig.yaml
```

### VM Storage
* **Boot Disks**: Stored on `moge_khatun` ZFS dataset
* **VM Configs**: Managed by Proxmox in `/etc/pve/nodes/`
* **Backups**: Automated via Proxmox to `borte` NAS

## Best Practices
1. **DHCP Reservations**: Always configure DHCP reservations before cloning
2. **Resource Planning**: Monitor storage usage on `moge_khatun` dataset
3. **Backup Strategy**: Template and VMs are covered by automated backup system
4. **Security**: Regularly update the base cloud image and recreate template
