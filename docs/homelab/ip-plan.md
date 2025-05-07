# 🌐 Homelab Networking Plan

## Network Details
* **Subnet:** `10.0.0.0/24`
* **Subnet Mask:** `255.255.255.0`
* **Gateway:** `10.0.0.1`
* **DNS Server:** `10.0.0.1` - *See DNS Resolution section below for future plans.*
* **ISP DHCP Range: `10.0.0.100` - `10.0.0.245`
* **Homelab Reserved Range:** `10.0.0.2` - `10.0.0.99`

## IP Allocation Strategy
* All core homelab devices (physical hosts, VMs, NAS) will receive a fixed IP address within the `10.0.0.2` - `10.0.0.99` range.
* Regular client devices (phones, laptops without reservations) will receive dynamic IPs from the `10.0.0.100` - `10.0.0.245` range.
* All devices configured with reservations **must** have their network interface set to obtain an IP address via **DHCP** within their respective operating systems.

## Reserved IP Addresses
| Hostname     | Device/Role                | Reserved IP      | Notes                                       |
| :----------- | :------------------------- | :--------------- | :------------------------------------------ |
| **Infrastructure & Physical** |             |                  |                                             |
| `Chingis`    | Main Workstation           | `10.0.0.7`      | Set Interface to DHCP                     |
| `mukhulai`   | Proxmox Host 1 / NFS Server| `10.0.0.10`      | Set Interface to DHCP                     |
| `borchi`     | Proxmox Host 2             | `10.0.0.11`      | Set Interface to DHCP                     |
| `borokhul`   | Proxmox Host 3             | `10.0.0.12`      | Set Interface to DHCP                     |
| *(Future Host)*| Proxmox Host 4           | `10.0.0.13`      | *(Reserved)* |
| *(Future Host)*| Proxmox Host 5           | `10.0.0.14`      | *(Reserved)* |
| `borte`      | Backup NAS                 | `10.0.0.19`      | Set Interface to DHCP                     |
| **Docker Swarm Managers (`Unench Nokhod`)** | |                |                                             |
| `gateway`   | Docker Engine VM         | `10.0.0.20`      | VM Network set to DHCP                  |
| `servarr`        | Docker Engine VM         | `10.0.0.21`      | VM Network set to DHCP                  |
| `ger`   | Docker Engine VM         | `10.0.0.22`      | VM Network set to DHCP                  |
| **Utility Services (Examples)** |             |                  |                                             |
| `pihole`     | Pi-hole VM     | `10.0.0.53`      | VM Network set to DHCP |
| `adguard`    | AdGuard Home VM | `10.0.0.54`      | VM Network set to DHCP |

## 🌐 Local DNS Resolution with Pi-hole
While Pi-hole is widely known as a network-level ad-blocker, it also serves a crucial function in this homelab as the **primary internal DNS server**.
* Pi-hole allows defining custom **Local DNS Records** via its web interface.
* We map the easy-to-remember hostnames defined in the [Naming Convention](./naming-convention.md) to their corresponding static IP addresses.
    * Example Record 1: `mukhulai.lan` -> `10.0.0.10`
    * Example Record 2: `gateway.lan` -> `10.0.0.20`

**Choosing a Domain Suffix:**
* It is strongly recommended to use a private domain suffix like **`.lan`** or **`.internal`** for these local records.
* **Avoid using `.local`**, as it is reserved for mDNS/Bonjour/Avahi and using it in Pi-hole can cause conflicts.

**Result:**
* Once Pi-hole is running (e.g., on its reserved IP `10.0.0.53`) and the DHCP server is configured to assign Pi-hole's IP as the DNS server to all network clients, we can access homelab devices and services using their hostnames plus the chosen suffix.
* Examples:
    * `ssh user@mukhulai.lan` (instead of `ssh user@10.0.0.10`)
    * Services configured to talk to each other can use these internal names.

**Setup Overview:**
1.  Deploy Pi-hole (VM or container) with a reserved static IP (e.g., `10.0.0.53`).
2.  Add A records for homelab devices in Pi-hole's "Local DNS Records" section.
3.  Configure the DHCP settings to distribute Pi-hole's IP as the DNS server.
4.  (Optional) Configure Pi-hole's upstream DNS servers as desired (e.g., Cloudflare, Google, Quad9, or Unbound).

This setup significantly improves the usability and manageability of the homelab by providing reliable name resolution for internal services.
