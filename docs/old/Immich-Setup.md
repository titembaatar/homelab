# 📷 Immich Setup
This guide provides detailed instructions for setting up and configuring Immich, a self-hosted photo and video backup solution, in your homelab environment.

## 🖥️ LXC Container Configuration
Create a dedicated LXC container for Immich with the following specifications:
### Container Specs
```bash
# Recommended configuration
cores: 4
memory: 8192 MB
swap: 8192 MB
storage: 32GB (rootfs)
```

### Essential Configuration
Edit your LXC config file (`/etc/pve/lxc/<lxc-id>.conf`) to include:
```conf
mp0: /vault/db,mp=/data,size=15000G
mp1: /config/config,mp=/config,size=256G

# Enable hardware acceleration for Intel QuickSync
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 29:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
```

> **Important**: Direct ZFS dataset mounting is strongly recommended over SMB shares to avoid permission issues with the PostgreSQL database.
> Or you can use NFS shares with `chown 101000:101000` to get a `chown 1000:1000` on the LXC and set `user: 1000:1000` in the `docker-compose.yml`
> More info in the [Files Sharing section](./Files-Sharing) or [LXC Setup section](./LXC-Setup).

## 📋 Prerequisites
### Inside the Container
Install Docker and other required packages following the [Docker Environment](./Docker-Environment) guide.

### Directory Structure
Create the necessary directories:
```bash
# For configuration
mkdir -p /config/homelab/volumes/immich/config
mkdir -p /config/homelab/compose/immich

# For media library and database
mkdir -p /data/immich/library
mkdir -p /data/immich/postgres

# For machine learning cache on local storage
mkdir -p /var/lib/immich/ml-cache
```

> PostgreSQL is really annoying with permissions. What you need to do is change ownership on the proxmox host to <user-id>+100000.  
> So for example, if your user have `uid=1000` you need to set ownership to `101000` on the proxmox host, it will become `1000` on the LXC.  
> And finally add `user: 1000:1000` for both the `database` and `immich-server`.
> More info in the [Files Sharing section](./Files-Sharing) or [LXC Setup section](./LXC-Setup).

### 🐳 Docker Key `.env` variables
```
# Storage locations
UPLOAD_LOCATION=/data/immich/library
DB_DATA_LOCATION=/data/immich/postgres
ML_CACHE_LOCATION=/var/lib/immich/ml-cache

# Timezone
TZ=Europe/Paris

# Version
IMMICH_VERSION=release
```

## 🚀 Deployment
Start the Immich services using Docker Compose:
```bash
cd /config/homelab/compose/immich
docker-compose up -d
```

## 🌐 Accessing Immich
Once everything is up and running, access Immich at:
```
http://<container-ip>:2283
```

### Reverse Proxy Configuration (Optional)
To access Immich through your Caddy reverse proxy, add a Caddyfile entry:
```
immich.yourdomain.com {
    reverse_proxy <container-ip>:2283
}
```

## 📊 Resource Considerations
### CPU Usage
- **Transcoding**: High CPU utilization during video transcoding if hardware acceleration isn't working
- **Machine Learning**: CPU-intensive during initial library scanning for face recognition and object detection

### Memory Usage
- **Minimum**: 4GB RAM
- **Recommended**: 8GB+ RAM for larger libraries
- **Machine Learning**: May require up to 2GB of additional memory

### Storage Requirements
- **Database**: Scales with library size (approximately 25% of total photo count in MB)
- **ML Cache**: 2-5GB for machine learning models
- **Media**: Plan storage based on your library size
  - 500 RAW photos ≈ 15GB
  - 1 hour of 4K video ≈ 5GB

## 🔍 Troubleshooting
### Hardware Acceleration Issues
If hardware transcoding isn't working:
```bash
# Check if the i915 module is loaded on the host
lsmod | grep i915

# Verify device access inside the container
docker exec -it immich_server ls -la /dev/dri
```

### Machine Learning
If machine learning is slow or causing issues:
```bash
# Disable machine learning temporarily
# Edit .env file and set:
MACHINE_LEARNING_ENABLED=false

# Restart the container
docker-compose restart immich-machine-learning
```
