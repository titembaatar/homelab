# 🐳 Docker Environment
This guide provides detailed instructions for setting up and managing Docker containers in your homelab.

## 📥 Installation
Install Docker on your LXC container with the following commands:
```bash
sudo dnf up -y
sudo dnf -y install dnf-plugins-core
sudo dnf-3 -y config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo systemctl status docker
```

## 👤 User Configuration
Add your user to the Docker group to avoid using `sudo` for Docker commands:
```bash
sudo usermod -aG docker titem
sudo newgrp docker
su titem
zsh
docker ps # to verify permissions
```

## 🌐 Proxy Network
If you plan to use a reverse proxy (like Caddy), create a dedicated Docker network:
```bash
docker network create proxy
```

This network allows containers to communicate with your proxy while keeping them isolated from other containers.

## 🛠️ Container Management Tools
### Lazydocker
Lazydocker provides a TUI for managing Docker containers:
```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

Add an alias for quicker access:
```bash
echo "alias lzd='lazydocker'" >> ~/.zshrc
source ~/.zshrc
```

## 📂 Directory Structure
All Docker-related files follow this structure:
```
/config/homelab/
├── compose/
│   └── <container-name>/
│       ├── docker-compose.yml
│       └── .env
└── volumes/
    └── <container-name>/
        └── <volume-directories>
```

## 🤖 Helper Scripts
### Container Creation Script
The `add_container.sh` script automates container setup and integration with your proxy. It:
1. Creates directory structure for your container
2. Generates container configuration files
3. Starts the container
4. Optionally adds it to your [Caddy proxy](./Caddy-Proxy)

#### Example Use Case
To create a new container for Nextcloud:
1. Run `./scripts/add_container.sh`
2. Enter details:
   - Container name: `nextcloud`
   - Image: `nextcloud:latest`
   - Ports: `80`
   - Environment: Add database connection details
   - Volumes: `config data`
   - Use vault: `yes`
   - Add to proxy: `yes`

After completion, you'll have a running Nextcloud instance accessible through your Caddy proxy.

## ⚡ Related Guides
- For setting up the reverse proxy, see [Caddy Proxy](./Caddy-Proxy)
- For configuring DNS resolution, see [Network Setup](./Network-Setup)
- For application-specific setup, like [Immich Setup](./Immich-Setup)
- For backing up your Docker volumes, see [Backup Strategy](./Backup-Strategy)

## 🔍 Troubleshooting
### Common Issues

1. **Container won't start**
   - Check logs: `docker logs <container-name>`
   - Verify permissions on volume directories

2. **Network connectivity issues**
   - Ensure the container is on the correct network
   - Check if ports are properly mapped
   - Verify [Pi-hole DNS configuration](./Network-Setup) if using with Tailscale

3. **Volume mount problems**
   - Verify the directory exists on the host
   - Check user/group permissions (PUID/PGID)
