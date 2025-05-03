# 📥 Homelab Backup Strategy

## Philosophy

Backup strategy to protect against various failure scenarios.  
The goal is to ensure recoverability for critical configurations, persistent application data,
and the underlying virtual infrastructure, balancing backup scope, storage space, and complexity.

## Backup Components & Methods

### 1. Proxmox Virtual Machines (Swarm Nodes & Others)
* **Method:** Proxmox VE's built-in backup feature (vzdump). This creates full backups of the VM disk images.
* **Schedule:** Runs automatically via Proxmox GUI scheduling (typically Daily).
* **Target:** Backups are stored on the `Borte` NAS (Synology DS220+) via an NFS mount point configured in Proxmox Datacenter -> Storage (e.g., `/mnt/pve/borte` targeting the `borte/proxmox-backups/` share).
* **Retention:** Configured within the Proxmox backup job(s) to keep:
    * 7 Daily Backups
    * 4 Weekly Backups
    * 12 Monthly Backups
    * 2 Yearly Backups
* **Scope:** Backs up the entire VM disk image, allowing for full VM restores in case of VM corruption or host failure.

### 2. ZFS Datasets (NFS Shares - Configs, DBs, etc.)
This covers the critical persistent data stored on NFS shares hosted on ZFS datasets (primarily from `mukhulai`).

* **Method:** A custom script (`zfs_backup.sh`) utilizes ZFS snapshots and `zfs send` to create full, independent backup files for specified datasets.
    * For detailed script operation, configuration (`config.yml`), and restoration steps, see [ZFS Backup Script Details](../scripts/zfs_backup.md)
* **Schedule:** Managed via `crontab` on the NFS host (`mukhulai`), running different frequencies corresponding to the retention policy:
    ```cron
    # Crontab Schedule on mukhulai
    0 2 * * * /path/to/zfs_backup.sh daily
    0 3 * * 7 /path/to/zfs_backup.sh weekly
    0 4 1 * * /path/to/zfs_backup.sh monthly
    0 5 1 1 * /path/to/zfs_backup.sh yearly
    ```
* **Target:** Backup files are stored on the `Borte` NAS, organized by frequency within the ZFS backup directory (e.g., `/mnt/pve/borte/zfs_backup/{daily, weekly, ...}`).
* **Retention:** Configured within the script's `config.yml` to match the overall retention policy:
    * Keep 7 Daily Backups
    * Keep 4 Weekly Backups
    * Keep 12 Monthly Backups
    * Keep 2 Yearly Backups
    * Old backups for each dataset and frequency are automatically pruned by the script.
* **Scope:** Configured via the `datasets:` list in `config.yml` to back up the following critical datasets:
    * `flash/yesugen` (Application Config Files)
    * `flash/yesui` (Docker Compose/Stack Files & Repo)
    * `vault/khulan` (Databases)
* **Exclusions:** The large media dataset `vault/juerbiesu` is **intentionally excluded** from this backup routine as the data is considered non-critical or easily replaceable, and the storage requirements would be excessive.

### 3. Container Application Data
* Most persistent application data (configurations, databases) resides on the ZFS datasets (`flash/yesugen`, `vault/khulan`) covered by the `zfs_backup.sh` script.
* Data stored within containers on ephemeral storage or non-backed-up volumes will **not** be persisted or backed up.

### 4. Configuration Files (Stack Files, Docs)
* Docker stack files (`docker-compose.yml`), documentation (`docs/`), helper scripts (`zfs_backup.sh`), and related non-secret configuration are version controlled using Git.
* The primary working copy resides on the `flash/yesui` ZFS dataset, which is backed up by the ZFS script.
* Regular pushes to the remote GitHub repository provide an **offsite backup** for this critical configuration infrastructure.

## Recovery Procedures
* **VMs:** Use the Proxmox VE GUI ("Restore" option from the `Borte` backup storage).
* **ZFS Datasets:** Use the `zfs receive` command on the target system (likely `mukhulai`) with the desired `.zfs` backup file retrieved from `Borte`.
* **Configuration/Code:** Clone the Git repository from GitHub.

## Verification
* Regularly check Proxmox backup job logs and ZFS backup script logs for success.
* Periodically test ZFS backup integrity using `zfs receive -n`.
* Perform test restores occasionally (e.g., restore a non-critical VM or a ZFS dataset to a test location/name) to ensure backups are viable and the recovery process is understood.

