# 🏷️ Naming Convention

## 🖥️ Main Workstation
| Type | Name | Description |
|------|------|-------------|
| Main Computer | `Chingis` | Primary workstation |

## 🏇 Proxmox Cluster (`Khuleg Baatar` - Brave Warriors)
| Node | Name | Role | Description |
|------|------|------|-------------|
| Node 1 | `Mukhulai` | Proxmox Host | One of the trusted and esteemed Chingis Khan's generals |
| Node 2 | `Borchi` | Proxmox Host | One of the first and most loyal of Chingis Khan's friends and allies |
| Node 3 | `Borokhul` | Proxmox Host | One of member of Chingis Khan's inner council and most trusted advisors|

## Docker Engines
| VM | Host | Description |
|----|------|-------------|
| Ger | `Mukhulai` | For services like Immich, vaultwarden... |
| Servarr | `Borchi` | *arr stack |
| Gateway | `Borokhul` | Traefik, Cloudflared, Crowdsec, Tinyauth |

## 💽 Storage Pools (Named after Chingis Khan's wifes)
| Type | Name | Description |
|------|------|-------------|
| Backup NAS | `Borte` | Backup storage - First Wife, head of the Chingis Khan's Court, and Grand Empress of his Empire|
| ZFS 1.1 | `Juerbiesu` | Media - Empress of Qara Khitai, Mongol Empire, and Naiman |
| ZFS 1.2 | `Khulan` | Databases - Managed one of the largest Ordu (camp) |
| ZFS 2.1 | `Yesugen` | Config Files for services - Youngest Tatars sister |
| ZFS 2.2 | `Yesui` | Homelab repo - Eldest Tatars sister |
| ZFS 2.3 | `Moge-Khatun` | VM boot disks - Chingis Khan's concubine, later wife of one of his sons |
