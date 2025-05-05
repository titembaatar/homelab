# ⚙️ Proxmox VE Cluster Setup Guide

This document outlines the steps to create the Proxmox VE cluster (`Khuleg Baatar`)
and configure the necessary storage resources within the Datacenter view.

## Prerequisites
Before creating the cluster, ensure the following conditions are met on all three Proxmox nodes (`mukhulai`, `borchi`, `borokhul`):

* **Proxmox VE Installed:** Proxmox VE is installed and running on each node.
* **Network Configuration:** Each node has its network interface configured to use DHCP.
* **Static IP Assignment:** DHCP Reservations have been configured on the DHCP server to assign the correct static IPs based on each node's MAC address:
    * `mukhulai`: `10.0.0.10`
    * `borchi`: `10.0.0.11`
    * `borokhul`: `10.0.0.12`
* **Hostname Resolution:** Ensure nodes can resolve each other's hostnames. Before Pi-hole is set up, you may need to temporarily add entries to `/etc/hosts` on each node:
    ```bash
    # Example /etc/hosts entries (add on all 3 nodes)
    10.0.0.10 mukhulai.lan mukhulai
    10.0.0.11 borchi.lan borchi
    10.0.0.12 borokhul.lan borokhul
    ```
    *(Adjust `.lan` suffix if you choose a different one)*
* **Time Synchronization:** Verify that all nodes have their time synchronized using NTP. Check `systemctl status systemd-timesyncd.service` or your configured NTP client. Consistent time is critical for cluster operations.
* **SSH Access:** You have SSH access to all nodes.

## 2. Create the Cluster
Choose **one node** to initiate the cluster creation. We will use `mukhulai` (`10.0.0.10`) as the first node.

1.  **SSH into the first node:**
    ```bash
    ssh root@10.0.0.10
    ```
2.  **Create the cluster:**
    ```bash
    pvecm create khuleg-baatar
    ```
3.  **Verify:** Check the cluster status on the first node. It will show one node and likely complain about no quorum (this is expected until more nodes join).
    ```bash
    pvecm status
    ```

## 3. Join Nodes to the Cluster
Now, add the remaining nodes (`borchi` and `borokhul`) to the cluster.

1.  **SSH into `borchi`:**
    ```bash
    ssh root@10.0.0.11
    ```
2.  **Add the node to the cluster:** Use the IP address `mukhulai`. You will be prompted for the root password of `mukhulai` to establish trust.
    ```bash
    pvecm add 10.0.0.10
    ```
3.  **SSH into `borokhul`:**
    ```bash
    ssh root@10.0.0.12
    ```
4.  **Add the third node to the cluster:**
    ```bash
    pvecm add 10.0.0.10
    ```

## 4. Verify Cluster Status
From the Proxmox web UI of *any* node (e.g., `https://10.0.0.10:8006`), or via SSH on any node, verify the cluster status again:

```bash
pvecm status
```

You should now see all three nodes listed, and the output should indicate that quorum is established ("Quorate: Yes").
The Proxmox web UI (Datacenter view) should also show all three nodes.

## 5. Configure Datacenter Storage
Now, configure the storage resources that will be available across the cluster in the Proxmox Datacenter view.

1.  **Access Proxmox Web UI:** Log into the web interface of any node.
2.  **Navigate to Storage:** Go to `Datacenter` -> `Storage`.
3.  **Add NFS Storage:**
    * Click `Add` -> `NFS`.
    * **ID:** `<nfs_share>`
    * **Server:** `10.0.0.10` (IP of `mukhulai`)
    * **Export:** Select or manually enter **one** of the exported paths (e.g., `/flash/yesugen`).
    * **Content:** none
    * **Nodes:** Select *all* nodes.
    * **Enable:** Ensure it's enabled.
    * Click `Add`.
4.  **Add NFS Storage (Backups):**
    * Click `Add` -> `NFS`.
    * **ID:** `backups`
    * **Server:** `10.0.0.19` (IP of `Borte`)
    * **Export:** Enter the path to your backup share.
    * **Content:** Select **only** `VZDump backup file`.
    * **Max Backups:** Set your desired retention here (e.g., 7 daily, 4 weekly etc. - Proxmox manages this).
    * **Nodes:** Select *all* nodes.
    * **Enable:** Ensure it's enabled.
    * Click `Add`.

Your Proxmox cluster is now formed, and the essential storage locations (local storage on each node for VMs, shared NFS for ISOs/Snippets, NFS for backups) are configured and available for creating VMs and scheduling backups. Shared data for containers will be handled via Docker NFS volumes later.
