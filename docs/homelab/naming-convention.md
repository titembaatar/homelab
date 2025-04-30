#  Naming Convention

## 󰍹 Main Workstation
| Type | Name | Description |
|------|------|-------------|
| Main Computer | `Chingis` | Primary workstation |

##  Proxmox Cluster (`Khuleg Baatar` - Brave Warriors)
| Node | Name | Role | Description |
|------|------|------|-------------|
| Node 1 | `Mukhulai` | Proxmox Host | One of the trusted and esteemed Chingis Khan's generals |
| Node 2 | `Borchi` | Proxmox Host | One of the first and most loyal of Chingis Khan's friends and allies |
| Node 3 | `Borokhul` | Proxmox Host | One of member of Chingis Khan's inner council and most trusted advisors|

## 󰩃 Docker Swarm Managers (`Unench Nokhod` - Loyal Dogs)
| VM | Name | Host | Description |
|----|------|------|-------------|
| Manager 1 | `Subeedei` | `Mukhulai` | Primary military strategist of Chingis Khan |
| Manager 2 | `Zev` | `Borchi` | Originally an enemy soldier, turned into one of Chingis Khan's greatest generals |
| Manager 3 | `Khubilai` | `Borokhul` | Skilled and loyal military leader to Genghis Khan |

## 󱖿 Docker Swarm Workers (Named after tribes of the `Unench Nokhod`)
| Worker | Name | Manager | Description |
|--------|------|---------|-------------|
| Worker 1 | `Uriankhai` | `Subeedei` | The Uriankhai tribe, known for their elite warriors |
| Worker 2 | `Besud` | `Zev` | The Besud tribe, one of the core Mongol tribes |
| Worker 3 | `Baarin` | `Khubilai` | The Baarin tribe, loyal to Chingis Khan |

##  Storage Pools (Named after Chingis Khan's wifes)
| Type | Name | Description |
|------|------|-------------|
| ZFS 1.1 | `Juerbiesu` | Media - Empress of Qara Khitai, Mongol Empire, and Naiman |
| ZFS 1.2 | `Khulan` | Databases - Managed one of the largest camps |
| ZFS 2.1 | `Yesugen` | Config Files - Youngest Tatars sister |
| ZFS 2.2 | `Yesui` | Compose Files - Eldest Tatars sister |
| ZFS 2.3 | `Moge-Khatun` | VM boot disks - Chingis Khan's concubine, later wife of one of his sons |
| Backup NAS | `Borte` | Backup storage - First Wife, head of the Chingis Khan's Court, and Grand Empress of his Empire|

