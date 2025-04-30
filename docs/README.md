#  Homelab Wiki

##  Homelab Components

###  My Homelab
* [ Naming Convention](./homelab/naming-convention.md) - Naming inspired by Chingis Khan's Empire
* [󰉋 Directory Structure](./homelab/directory-structure.md) - ZFS Pools/Subpools structure

###  Core Setup
* [ Proxmox ZFS Pools](./proxmox/zfs-pools.md) - Storage creation and sharing via NFS/SMB
* [ Proxmox Cluster](./proxmox/cluster.md) - Proxmox cluster creation
* [ VMs Setup ](./proxmox/vms-setup.md) - Setting up a blank VMs
* [ Proxmox HA](./proxmox/ha.md) - Proxmox HA setup

###  Environments
* [ Docker](./env/docker.md) - Quick install of docker on VMs
* [ Docker Swarm](./env/docker-swarm.md) - Setup of Docker Swarm

###  Stacks/Containers
* Gateway Stack :
    * [󰌾 Caddy Reverse Proxy](./con/caddy-reverse-proxy.md)
    * [󱠾 Pangolin Tunnel](./con/pangolin-tunnel.md)
    * [󰓠 Crowdsec and Fail2Ban](./con/crowdsec-fail2ban.md)
* [󰄀 Immich (DB container example)](./con/immich.md)

### 󰁯 Backup
* [󰁯 Backup Strategy](./backup/strategy.md) - Backup strategy for VMs, ZFS subpools etc...

## 󰯁 Automation Scripts
Here is several helper scripts concatenate in my tool [flem](https://github.com/titembaatar/flem) to make deployment easier:

| Script | Purpose |
|--------|---------|
| `add_container.sh` | Streamlines Docker container deployment |
| `caddy/add_app.sh` | Add Caddy reverse proxy entries |
| `caddy/install.sh` | Install the Caddy reverse proxy LXC |
| `network/install.sh` | Install Tailscale and Pi-hole LXC |
| `lxc_samba/lxc_cifs_share.sh` | Mount SMB/CIFS shares to LXC containers |
| `backups/zfs_backup.sh` | Handles ZFS snapshot backups, with config file |

