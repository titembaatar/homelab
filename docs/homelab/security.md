# 🔒 Homelab Security Approach

## Core Security Components & Strategies
1.  **Perimeter Security & IP Obfuscation (Cloudflare Tunnels):**
    * **Mechanism:** The `cloudflared` service establishes an outbound-only tunnel to Cloudflare's edge network. No inbound ports need to be opened on the ISP router firewall.
    * **Benefit:** This completely hides the home public IP address from users accessing services, mitigating direct scans and attacks. It also leverages Cloudflare's infrastructure for potential DDoS mitigation at the edge.

2.  **TLS Termination & Reverse Proxy (Caddy):**
    * **Mechanism:** Caddy runs internally and is the target for the Cloudflare Tunnel. It terminates TLS connections using valid Let's Encrypt certificates (obtained via the Cloudflare DNS challenge). It then proxies requests to the appropriate backend application container based on hostname.
    * **Benefit:** Ensures encrypted communication (HTTPS) for all exposed services. Acts as a single, manageable ingress point within the Docker Swarm network.

3.  **Intrusion Detection & Prevention (CrowdSec):**
    * **Mechanism:** The CrowdSec agent analyzes Caddy's access logs for malicious patterns (scans, credential stuffing, exploits, etc.) identified by community-driven scenarios. Detected malicious IPs are shared with bouncers.
    * **Bouncers:**
        * `crowdsec-caddy-bouncer`: Instructs Caddy (via its API) to deny requests from banned IPs.
        * `crowdsec-cloudflare-bouncer`: Instructs Cloudflare (via its API) to block banned IPs at the network edge, preventing them from even reaching the tunnel.
    * **Benefit:** Proactively blocks known bad actors and abusive traffic before they can significantly impact services or attempt further exploits.

4.  **Application Access Control (TinyAuth):**
    * **Mechanism:** For services requiring user authentication before access (e.g., dashboards, potentially shared photo access), Caddy uses `forward_auth` to delegate the authentication check to the TinyAuth service.
    * **Benefit:** Ensures that only authenticated users can access specific applications, even if those applications are technically reachable via the Cloudflare Tunnel and Caddy. Provides a necessary layer beyond simple network reachability.

5.  **Sensitive Data Protection (Docker Secrets):**
    * **Mechanism:** Docker Swarm's built-in Secrets management is used for storing and distributing sensitive information like API keys (Cloudflare, CrowdSec, Notifiarr, etc.), passwords (TinyAuth user hashes, database passwords), and tokens (`TUNNEL_TOKEN`).
    * **Benefit:** Secrets are encrypted at rest and in transit within the Swarm control plane, only mounted into containers that explicitly require them (typically as read-only files in `/run/secrets/`). This avoids storing sensitive data directly in environment variables, configuration files, or Git.

6.  **Container Isolation (Docker Networking):**
    * **Mechanism:** Services are placed on specific Docker overlay networks (e.g., `caddy_net` for ingress-exposed services, `media_internal` for backend communication). By default, containers can only communicate with others on the same Docker network(s).
    * **Benefit:** Provides a basic level of network segmentation at the container level, limiting the potential blast radius if one container is compromised.

## Other Practices
* **Regular Updates:** Maintaining up-to-date software for the underlying OS (Proxmox, Debian VMs), Docker Engine, and container images is critical for patching known vulnerabilities. *(See [Maintenance Philosophy](./maintenance.md) - Link TBD)*.
* **Firewalling:** Host-level firewalls (`ufw` or Proxmox firewall) should be configured on VMs and hosts to restrict unnecessary internal traffic, complementing the closed external firewall.
* **Principle of Least Privilege:** Strive to run container processes as non-root users where images support it, and only grant necessary capabilities (`cap_add`) or permissions.

## Future Considerations
* **Network Segmentation (VLANs):** Implementing VLANs on the physical network (requires capable switch like the TL-SG608E and router/firewall configuration) could provide stronger isolation between different types of devices (e.g., servers vs. IoT vs. user devices) in the future.
