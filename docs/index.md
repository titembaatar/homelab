# 📑 Homelab Wiki

## 🚀 Quick Start
```bash
# 1. Deploy Gateway (Swarm Manager)
runs/gateway

# 2. Deploy Servarr Stack
runs/servarr <manager_ip> <worker_token>

# 3. Deploy Ger Services
runs/ger <manager_ip> <worker_token>
```

For detailed deployment instructions, see [Docker Setup](./docker/setup.md).

## 🐎 My Homelab
* [🏷️ Naming Convention](./homelab/naming-convention.md) - Naming inspired by Chingis Khan's Empire
* [📁 Directory Structure](./homelab/directory-structure.md) - ZFS Pools/Subpools structure
* [🌐 Networking Plan](./homelab/ip-plan.md) - IP addressing scheme for the homelab network
* [📥 Homelab Backup Strategy](./homelab/backup.md) - Comprehensive backup strategy
* [🔧 Troubleshooting](./homelab/troubleshooting.md) - Common issues and solutions

## 🖥️ Infrastructure
### Proxmox
* [💽 ZFS, NFS & SMB](./proxmox/zfs-nfs-smb-share.md) - Configure ZFS datasets and set up NFS and SMB shares
* [⚙️ Proxmox VE Cluster](./proxmox/cluster.md) - Setup Proxmox cluster
* [🖥️ VM Template](./proxmox/vm-template.md) - Create and manage Debian VM templates

### Docker
* [🐋 Setup Docker VMs](./docker/setup.md) - Automated Docker Swarm deployment system
* [⚙️ Environment Variables](./docker/env-and-secrets.md) - Configuration and secrets management

