# 🔧 Troubleshooting Guide
## 🐋 Docker & Docker Swarm Issues
### Docker Swarm Node Issues
**Problem**: Node shows as "Down" in `docker node ls`
```bash
# Check node status
docker node ls

# Inspect specific node
docker node inspect <node-name>

# Force remove dead node (from manager)
docker node rm --force <node-name>

# Rejoin worker node
homelab <node-name> scripts/docker/worker.sh <token> <manager-ip>
```

**Problem**: Services not starting on specific nodes
```bash
# Check service constraints
docker service inspect <service-name>

# View service logs
docker service logs <service-name>

# Check node availability
docker node update --availability active <node-name>
```

### Docker Compose Issues
**Problem**: `docker compose up` fails with network errors
```bash
# Recreate networks
docker network prune -f
docker network create <network-name>

# Check network connectivity
docker network ls
docker network inspect <network-name>
```

**Problem**: Container can't connect to NFS volumes
```bash
# Test NFS connectivity from container host
showmount -e 10.0.0.10

# Check mount inside container
docker exec -it <container> df -h

# Verify NFS server status
systemctl status nfs-kernel-server
```

### Volume and Storage Issues
**Problem**: Permission denied on NFS volumes
```bash
# Check ownership on NFS server
ls -la /vault/juerbiesu

# Fix ownership (on NFS server - mukhulai)
chown -R 1000:1000 /vault/juerbiesu /vault/khulan /flash/yesugen

# Check container user
docker exec -it <container> id
```

**Problem**: "No space left on device" errors
```bash
# Check disk usage
df -h
zfs list -o space

# Clean up Docker
docker system prune -af
docker volume prune -f

# Check ZFS pool usage
zpool list
```

## 🌐 Network & Connectivity Issues
### SSH Connection Problems
**Problem**: Can't SSH to VMs after deployment
```bash
# Check VM is running
qm status <vm-id>

# Verify IP assignment
ping <vm-ip>

# Test SSH with specific key
ssh -i ~/.ssh/mukhulai titem@<vm-ip>

# Check SSH service on VM
systemctl status ssh
```

**Problem**: SSH key authentication fails
```bash
# Verify SSH key exists
ls -la ~/.ssh/mukhulai*

# Check key permissions
chmod 600 ~/.ssh/mukhulai
chmod 644 ~/.ssh/mukhulai.pub

# Add key to SSH agent
ssh-add ~/.ssh/mukhulai
```

### Network Connectivity Issues
**Problem**: Services can't reach each other
```bash
# Check Docker networks
docker network ls
docker network inspect caddy_net

# Test connectivity between containers
docker exec -it <container1> ping <container2>

# Check firewall rules
ufw status
```

**Problem**: External access to services fails
```bash
# Check Caddy configuration
docker logs caddy

# Verify DNS resolution
nslookup <domain>

# Check SSL certificates
curl -I https://<domain>
```

## 💾 Storage & ZFS Issues
### ZFS Dataset Problems
**Problem**: ZFS pool shows degraded state
```bash
# Check pool status
zpool status

# Check for errors
zpool status -v

# Scrub the pool
zfs scrub vault
zfs scrub flash
```

**Problem**: NFS exports not accessible
```bash
# Check NFS exports
showmount -e localhost
exportfs -v

# Restart NFS services
systemctl restart nfs-kernel-server

# Check NFS logs
journalctl -u nfs-kernel-server -f
```

**Problem**: SMB shares not accessible
```bash
# Check Samba status
systemctl status smbd nmbd

# Test Samba configuration
testparm

# List Samba shares
smbclient -L localhost -U titem
```

### Backup Issues
**Problem**: ZFS backup script fails
```bash
# Check backup script logs
tail -f /mnt/pve/borte/zfs_backup/log/*.log

# Test manual backup
sudo $HOME/homelab/scripts/backup/zfs_backup.sh daily

# Check backup destination space
df -h /mnt/pve/borte

# Verify ZFS send/receive works
zfs send vault/khulan@test | zfs receive vault/test-restore
```

## 🖥️ Proxmox & VM Issues
### VM Creation Problems
**Problem**: VM template creation fails
```bash
# Check storage availability
pvesm status

# Verify cloud image download
wget -O /tmp/test.iso https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# Check Proxmox storage configuration
cat /etc/pve/storage.cfg
```

**Problem**: VM cloning fails
```bash
# Check template exists
qm status 9000

# Verify storage space
df -h /mnt/pve/moge_khatun

# Check VM configuration
qm config <vm-id>
```

### VM Boot Issues
**Problem**: VM won't start after cloning
```bash
# Check VM configuration
qm config <vm-id>

# Start VM manually
qm start <vm-id>

# Check VM console
qm monitor <vm-id>

# View VM logs
tail -f /var/log/qemu-server/<vm-id>.log
```

## 🔧 Homelab CLI Tool Issues
### CLI Tool Problems
**Problem**: `homelab` command not found
```bash
# Check if tool is installed
ls -la ~/.local/bin/homelab

# Reinstall CLI tool
$HOME/personal/homelab/runs/install.sh

# Check PATH
echo $PATH | grep -q "$HOME/.local/bin"
```

**Problem**: Remote script execution fails
```bash
# Test SSH connectivity
ssh <target-host> "hostname"

# Run with verbose output
homelab -d <target-host> <script-path>
```

## 🔐 Authentication & Access Issues
### Service Authentication Problems
**Problem**: Can't access services behind Tinyauth
```bash
# Check Tinyauth service
docker logs tinyauth

# Verify OAuth configuration
cat /mnt/yesugen/tinyauth/users/users_file

# Test direct service access (bypass auth)
curl -I http://<service-ip>:<port>
```

**Problem**: SSL certificate issues
```bash
# Check Caddy logs
docker logs caddy

# Verify DNS records
dig <your-domain>

# Test SSL manually
openssl s_client -connect <your-domain>:443
```

## 📊 Monitoring & Logs
### Useful Commands for Diagnosis
**Docker Service Debugging:**
```bash
# View all services status
docker service ls

# Detailed service information
docker service ps <service-name> --no-trunc

# Service logs with timestamps
docker service logs -t -f <service-name>

# Container resource usage
docker stats
```

**System Resource Monitoring:**
```bash
# Memory usage
free -h

# Disk usage
df -h
zpool list

# Network connectivity
ss -tulpn
netstat -rn
```

**Log Analysis:**
```bash
# System logs
journalctl -f

# Docker daemon logs
journalctl -u docker -f

# NFS logs
journalctl -u nfs-kernel-server -f

# SSH logs
journalctl -u ssh -f
```

## 🆘 Emergency Recovery
### Complete Service Recovery
**If entire homelab is down:**
```bash
# 1. Check basic connectivity
ping 10.0.0.10  # NFS server
ping 10.0.0.20  # Gateway

# 2. Restart core services
homelab mukhulai scripts/proxmox/vm_template.sh  # Ensure template exists
runs/gateway                                     # Redeploy gateway
runs/servarr <manager-ip> <worker-token>         # Redeploy servarr
runs/ger <manager-ip> <worker-token>             # Redeploy ger
```

**If NFS server is down:**
```bash
# On mukhulai (10.0.0.10)
systemctl restart nfs-kernel-server
zpool import vault flash  # If pools need importing
exportfs -ra
```

**If Docker Swarm is broken:**
```bash
# Leave swarm on all nodes
docker swarm leave --force

# Reinitialize from gateway
homelab gateway scripts/docker/manager.sh

# Rejoin workers
homelab servarr scripts/docker/worker.sh <token> <manager-ip>
homelab ger scripts/docker/worker.sh <token> <manager-ip>
```

