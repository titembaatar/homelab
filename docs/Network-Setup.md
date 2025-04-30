# 🌐 Network Setup
This guide explains how to set up networking components for your homelab, focusing on Tailscale VPN and Pi-hole DNS.

## 📋 Prerequisites
Before starting, configure your LXC container to support network devices by adding these lines to `/etc/pve/lxc/<lxc-id>.conf`:
```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

These configurations enable the container to use TUN/TAP devices, which are required for VPN functionality.

## 🚀 Installation
The provided script `network/install.sh` automates the installation of both Tailscale and Pi-hole:
```bash
./scripts/network/install.sh
```

During installation, you'll be asked whether you want to install:
- Tailscale for VPN connectivity
- Pi-hole for network-wide ad blocking and DNS

## 🔒 Tailscale Configuration
### Post-Installation Setup
After installation:

1. Run the command displayed during installation to authenticate with Tailscale
2. Visit the provided URL to complete authentication
3. In the Tailscale admin console:
   - Go to the LXC device settings
   - Click "Edit routes settings..."
   - Validate the subnet routes (e.g., `10.0.0.0/24`)
   - Enable the "Exit node" option

### DNS Configuration
To use your Pi-hole as the DNS server for all Tailscale devices:

1. In the Tailscale admin console, go to the DNS tab
2. Add a nameserver with the IP of your LXC
3. Check "Override local DNS"

### Accessing Services
With Tailscale configured:
- All devices connected to your Tailscale network can access your internal services
- You can use your internal DNS names from anywhere
- Traffic is encrypted end-to-end

## 🕳️ Pi-hole Configuration
### Accessing the Admin Interface
After installation:
- Navigate to `https://<lxc-ip>/admin`
- Use the password displayed during installation
- To set a new password: `sudo pihole -a -p <new-password>`

### Recommended Configuration
#### Adding Blocklists
To enhance blocking capabilities:
1. Go to "Group Management" > "Adlists"
2. Add these recommended blocklists:
   - [hagezi/dns-blocklists multi pro list](https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#pro)
3. Run `sudo pihole -g` to update gravity (the blocklist)

#### Configuring Clients
Set your Pi-hole as the DNS server for:
- Your router (if you want pihole on your local network)
- Individual devices
- Your Tailscale network (as mentioned in the Tailscale section)

### Configuring DNS for Caddy Services
To ensure your Caddy-proxied services are accessible through Tailscale:

1. In the Pi-hole admin panel, go to "Local DNS" → "CNAME Records"
2. Add a wildcard entry for your domain:
   - Domain: `*.yourdomain.com`
   - Target Domain: `yourdomain.com`
   - TTL: `300` (5 minutes for testing, increase to `3600` later)
3. Then add an A record for the target domain:
   - Go to "Local DNS" → "DNS Records"
   - Add: `yourdomain.com` pointing to your Caddy LXC IP (e.g., `10.0.0.101`)

This configuration ensures that any subdomain of your domain (like `service.yourdomain.com`) will resolve to your Caddy reverse proxy, which will then direct traffic to the appropriate service based on your Caddyfile configuration.

For individual services that aren't part of your main domain, you can add specific A records as needed.

### Performance Optimization
For best performance:
- Allocate at least 1GB RAM to the LXC container
- Consider enabling the built-in DHCP server if needed
- Set up DNS over HTTPS (DoH) or DNS over TLS (DoT) for upstream queries

## ⚙️ Advanced Network Configuration
### UDP GRO Forwarding
The installation script enables UDP GRO (Generic Receive Offload) forwarding, which improves network performance, especially for Tailscale traffic:
```bash
sudo ethtool -K eth0 rx-udp-gro-forwarding on
```

A systemd service is created to ensure this setting persists across reboots.

### Firewall Settings
The script also enables IP forwarding by modifying `/etc/sysctl.d/99-tailscale.conf` with:
```
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
```

These settings allow the container to route traffic between networks, which is essential for Tailscale exit node functionality.

## 🛠️ Troubleshooting
### Common Issues
1. **Tailscale Connection Problems**
   - Check the Tailscale status: `sudo tailscale status`
   - Verify firewall rules: `sudo tailscale ping <another-device>`

2. **Pi-hole Not Blocking Ads**
   - Check if Pi-hole is used as DNS: `nslookup doubleclick.net`
   - Verify blocklists are updated: `sudo pihole -g`
   - Check Pi-hole status: `sudo pihole status`

3. **DNS Resolution Issues**
   - Check if upstream DNS is working: `dig @1.1.1.1 google.com`
   - Restart Pi-hole: `sudo systemctl restart pihole-FTL`
   - Check Pi-hole logs: `sudo pihole -t`

4. **Caddy Services Not Accessible via Tailscale**
   - Verify CNAME and A records in Pi-hole
   - Check if wildcards are properly configured
   - Test resolution: `nslookup service.yourdomain.com`
   - Ensure Caddy is properly configured and running
