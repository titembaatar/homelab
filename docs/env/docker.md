# 🐋 Docker Environment

## Installation
Install Docker with the following commands:
```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## User Configuration
Add user to the Docker group to avoid using `sudo` for Docker commands:
```bash
sudo usermod -aG docker titem
sudo newgrp docker
```

```bash
su titem
zsh
docker ps # to verify permissions
```

## Proxy Network
If you plan to use a reverse proxy (like Caddy), create a dedicated Docker network:
```bash
docker network create proxy
```

This network allows containers to communicate with your proxy while keeping them isolated from other containers.

## Lazydocker
Lazydocker provides a TUI for managing Docker containers:
```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

Add an alias for quicker access:
```bash
echo "alias lzd='lazydocker'" >> ~/.zshrc
source ~/.zshrc
```

