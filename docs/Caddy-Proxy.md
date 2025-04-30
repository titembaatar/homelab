# 🔐 Caddy Proxy
This guide explains how to set up and configure Caddy as a reverse proxy for your homelab services.

## 📋 Prerequisites
Before setting up Caddy:
1. Set up a domain with Cloudflare DNS
2. Create a Cloudflare API token with DNS editing permissions
3. Set up a [Docker environment](./Docker-Environment) on your LXC container
4. Configure network settings as described in [Network Setup](./Network-Setup)
5. Configure Pi-hole DNS records for your services (see [Configuring DNS for Caddy Services](./Network-Setup#configuring-dns-for-caddy-services))

## 🚀 Installation
### LXC Container Configuration
Before starting your Caddy LXC, add these lines to `/etc/pve/lxc/<lxc-id>.conf`:
```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### Installation Script
The provided script `caddy/install.sh` automates the installation process:
```bash
./scripts/caddy/install.sh
```

The script will:
1. Create the required directory structure
2. Generate a custom Dockerfile with Cloudflare DNS plugin
3. Create the initial Caddyfile
4. Set up environment files for Cloudflare API token
5. Create and start the Docker container

### Installation Walkthrough
During installation, you'll be prompted for:
- Your domain name
- Cloudflare email address
- Cloudflare API token
- Whether to use Let's Encrypt staging (recommended for testing)

## ⚙️ Configuration
The Caddyfile defines how Caddy handles requests:
```
{
  email {env.CF_EMAIL}
  acme_dns cloudflare {env.CF_API_TOKEN}
  acme_ca "https://acme-v02.api.letsencrypt.org/directory"
}

*.yourdomain.com {
  tls {
    dns cloudflare {env.CF_API_TOKEN}
  }
}

service.yourdomain.com {
  reverse_proxy "service-ip:port"
}
```

## 🔗 Adding Services
### Manual Method
To add a service to Caddy manually:
1. Edit the Caddyfile
2. Add a new block for your service:
   ```
   newservice.yourdomain.com {
     reverse_proxy "10.0.0.5:8080"
   }
   ```
3. Reload Caddy:
   ```bash
   docker exec caddy caddy reload --config /etc/caddy/Caddyfile
   ```

### Using the Helper Script
The `caddy/add_app.sh` script simplifies adding new services:
```bash
./scripts/caddy/add_app.sh
```

Or with parameters:
```bash
./scripts/caddy/add_app.sh --name "appname" --ip "10.0.0.5" --port "8080"
```

#### Special Cases
For services that use HTTPS internally (like Proxmox or Synology), use:
```bash
./scripts/caddy/add_app.sh --special-case --name "proxmox" --ip "10.0.0.2" --port "8006"
```

This adds the necessary configuration to handle TLS verification:
```
proxmox.yourdomain.com {
  reverse_proxy https://10.0.0.2:8006 {
    transport http {
      tls_insecure_skip_verify
    }
  }
}
```

## 🔄 Integrating with Docker Containers
The `add_container.sh` script can automatically add your containers to Caddy:
1. Run the container setup script
2. When prompted, choose to add to proxy
3. Select the port to expose
4. The script will SSH to your Caddy host and configure it

## 🌐 DNS Configuration for Tailscale Access
When using Caddy with Tailscale and Pi-hole, you need to configure DNS records to ensure your services are accessible through the Tailscale network:

1. Set up Pi-hole as the DNS server for your Tailscale network
2. Configure wildcard domains in Pi-hole to point to your Caddy server
3. See the detailed steps in [Configuring DNS for Caddy Services](./Network-Setup#configuring-dns-for-caddy-services)

This configuration ensures that requests for your services (like `myapp.yourdomain.com`) are properly resolved to your Caddy server when accessed through Tailscale.

## 🛠️ Troubleshooting
### Common Issues
1. **Certificate errors**
   - Verify Cloudflare API token permissions
   - Check Caddy logs: `docker logs caddy`

2. **"502 Bad Gateway" errors**
   - Ensure target service is running
   - Check if IP and port are correct
   - Verify network connectivity between Caddy and service

3. **Changes not taking effect**
   - Make sure you reloaded Caddy after changing Caddyfile
   - Check syntax of your Caddyfile

4. **Services not accessible via Tailscale**
   - Verify Pi-hole DNS configuration
   - Check if domain resolves to Caddy IP: `nslookup myapp.yourdomain.com`
   - Ensure Tailscale is using Pi-hole for DNS
