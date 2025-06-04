# 🐋 Setup Docker VMs

## Overview
The system consists of three main VMs running Docker services:

- **Gateway** (`gateway`) - Caddy reverse proxy and Tinyauth authentication
- **Servarr** (`servarr`) - Media automation stack (*arr services, qBittorrent, etc.)
- **Ger** (`ger`) - General services (Immich, Glance dashboard, etc.)

## Deployment Architecture
### Docker Swarm Network
The deployment uses Docker Swarm with overlay networks to enable service communication across VMs:
- **Manager Node**: `gateway` VM initializes the swarm and creates overlay networks
- **Worker Nodes**: `servarr` and `ger` VMs join as workers
- **Overlay Networks**: `caddy_net` for reverse proxy, `servarr_net` for media services

## Deployment System
### The `homelab` CLI Tool
The repository includes a CLI tool (`runs/homelab`) that automates remote script execution:

**Installation:**
```bash
$HOME/personal/homelab/runs/install.sh
```

**Usage:**
```bash
homelab <target_host> <script_path> [args...]
homelab -s  # List available scripts
homelab -l  # List SSH hosts
```

### Stack Deployment
#### Scripts
Located in `runs/` directory, these scripts handle full VM lifecycle:

**Gateway Deployment (`runs/gateway`):**
```bash
runs/gateway
```
- Creates `gateway` VM on `borokhul` node
- Installs Docker and initializes Swarm manager
- Deploys Caddy reverse proxy and Tinyauth

**Servarr Deployment (`runs/servarr`):**
```bash
runs/servarr <manager_ip> <worker_token>
```
- Creates `servarr` VM on `borchi` node
- Joins Docker Swarm as worker
- Deploys complete *arr media stack

**Ger Deployment (`runs/ger`):**
```bash
runs/ger <manager_ip> <worker_token>
```
- Creates `ger` VM on `mukhulai` node
- Joins Docker Swarm as worker
- Deploys Immich and Glance services

## Prerequisites
### SSH Configuration
Ensure SSH keys and host configurations are set up:
```bash
# Example ~/.ssh/config entries
Host mukhulai
    HostName 10.0.0.10
    User titem

Host gateway
    HostName 10.0.0.20
    User titem

Host servarr
    HostName 10.0.0.21
    User titem

Host ger
    HostName 10.0.0.22
    User titem
```

### VM Template
Create the base VM template first:
```bash
homelab mukhulai scripts/proxmox/vm_template.sh
```

### Storage Requirements
Ensure NFS shares are mounted on VMs:
- `/mnt/yesugen` - Configuration files
- `/mnt/juerbiesu` - Media storage
- `/mnt/khulan` - Database storage

