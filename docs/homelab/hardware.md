# 🛠️ Homelab Hardware

## 🏇 Proxmox Cluster (`Khuleg Baatar`)

### Node 1: `Mukhulai` (NFS Server Role)
* **Make/Model:** Custom
* **CPU:** Intel N100 (4C/4T) @ up to 3.4GHz
* **RAM:** 32GB DDR5 SODIMM
* **Storage:**
    * Boot: 237.5G LVM on `/dev/sdf3` (Proxmox OS & LVM Pool `pve`)
    * Other Internal: 5x 3.6T HDD (`sda`-`sde`), 2x 477G NVMe (`nvme0n1`, `nvme1n1`) - *ZFS*
* **Network:** Multiple Interfaces (incl. `enp1s0`), using `vmbr0` for VMs.
* **OS:** Proxmox VE 8.3.x (Debian 12 Bookworm base)

### Node 2: `Borchi`
* **Make/Model:** HP ProDesk 400 G3 DM
* **CPU:** Intel Core i5-6500T (4C/4T) @ 2.50GHz (Boost up to 3.1GHz)
* **RAM:** 16GB DDR4 SODIMM
* **Storage:**
    * Boot: 237.5G LVM on `/dev/sda3` (Proxmox OS & LVM Pool `pve`)
* **Network:** 1x 1GbE RJ45 (`enp1s0`), using `vmbr0` for VMs.
* **OS:** Proxmox VE 8.3.x (Debian 12 Bookworm base)

### Node 3: `Borokhul`
* **Make/Model:** Custom
* **CPU:** Intel Core i5-6500T (4C/4T) @ 2.50GHz (Boost up to 3.1GHz)
* **RAM:** 8GB DDR4 SODIMM
* **Storage:**
    * Boot: 64G LVM on `/dev/sda3` (Proxmox OS & LVM Pool `pve`)
* **Network:** 2x 1GbE RJ45 (`enp1s0`), using `vmbr0` for VMs.
* **OS:** Proxmox VE 8.3.x (Debian 12 Bookworm base)

## 💾 Storage Servers

### Backup NAS: `Borte`
* **Make/Model:** Synology DS220+
* **CPU:** Intel Celeron J4025 (2C/2T) @ 2.0GHz (Boost up to 2.9GHz)
* **RAM:** 2GB DDR4 SODIMM
* **Storage:** 2x 4TB Seagate IronWolf NAS HDD in RAID 1 (Mirror)
* **Network:** 1x 1GbE RJ45
* **OS:** Synology DSM 7.2.2-72806 Update 3

## 🖥️ Workstation

### `Chingis`
* **Make/Model:** Custom
* **Motherboard:** ASUS ROG STRIX Z690-G GAMING WIFI
* **CPU:** 12th Gen Intel Core i7-12700K (8P+4E Cores / 20 Threads) @ up to 5.0GHz
* **RAM:** 32GB DDR5
* **Storage:**
    * OS Drive (`nvme0n1`): 465.8G NVMe SSD
    * Data Drive (`nvme1n1`): 1.8T NVMe SSD
* **Network:** 1x Intel 2.5GbE RJ45 (`enp5s0`)
* **OS:** Fedora Linux 42 (Workstation Edition)

## 🔌 Network Gear
* **Router:** ISP router
* **Switch:** TP-Link TL-SG608E (8-Port Gigabit Managed Switch)
