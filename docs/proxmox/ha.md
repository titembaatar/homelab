# ❤️‍🔥 Proxmox HA

## Prerequisites
- Fully functional Proxmox cluster (see [Proxmox Cluster](./cluster.md))
- Shared storage accessible by all nodes (see [ZFS Pools](./zfs-pools.md))
- Three or more nodes for robust quorum
- Reliable network connectivity between all nodes

## Shared Storage Configuration
HA requires shared storage to enable VM migration between nodes.

1. Configure ZFS Pool Sharing
1. Enable NFS/SMB Sharing

> [!INFO]
>
> See [ZFS Pools](./zfs-pools.md)

## Configuring HA Services

1. Enable HA Services:
    * Check if HA services are running
    ```bash
    systemctl status pve-ha-lrm pve-ha-crm
    ```
    * If not running, start them
    ```bash
    systemctl start pve-ha-lrm pve-ha-crm
    systemctl enable pve-ha-lrm pve-ha-crm
    ```
2. Create HA Groups
    * HA groups define node preferences for VM placement.
    ```bash
    ha-manager groupadd trusted-dbs -nodes Mukhulai,Borchi
    ha-manager groupadd critical-apps -nodes Mukhulai,Borchi,Borokhul
    ha-manager groupadd general-vms -nodes Mukhulai,Borchi,Borokhul -nofailback 1
    ```

## Adding VMs to HA

1. Prepare VMs for HA
    * Check VM disk locations
    ```bash
    qm config VMID | grep scsi0
    ```
    * If needed, migrate VM disks to shared storage
    ```bash
    qm move-disk VMID scsi0 ha-pool --delete 1
    ```
2. Add VM to HA Group
    * Add VM to HA (replace VMID with actual VM ID)
    ```bash
    ha-manager add vm:VMID --group critical-apps
    ```
    * Configure additional parameters
    ```bash
    ha-manager set vm:VMID --max_restart 3 --max_relocate 2
    ```
3. Verify HA Status
    * Check all HA resources
    ```bash
    ha-manager status
    ```
    * View detailed information for specific VM
    ```bash
    ha-manager status vm:VMID
    ```

## Live Migration Configuration
1. Configure VM for Live Migration
    * Ensure VMs are properly configured:
    ```bash
    qm config VMID --hotplug 1 --agent 1
    ```
2. Test Live Migration
    ```bash
    qm migrate VMID TARGET_NODE --online
    ```

## Automatic Live Migration During Maintenance
Enable automatic live migration when placing a node in maintenance:
```bash
pvesh set /cluster/options --migration secure --migration_with_local_disks 1
```

## Testing HA Functionality
It's crucial to test HA functionality before relying on it:
1. Simulate node failure (run on the node to test)
    ```bash
    systemctl stop pve-cluster
    ```
2. On another node, check HA status to verify VMs are migrated
    ```bash
    ha-manager status
    ```

---
---
---
---
---

## Fencing Configuration
Fencing ensures failed nodes don't cause split-brain situations.

### Step 1: Configure Fencing Devices

For physical servers with IPMI/iLO:

```bash
# Install fence agents
apt-get install fence-agents

# Create fencing configuration for each node
mkdir -p /etc/pve/ha/fence
```

Create file `/etc/pve/ha/fence/Mukhulai.cfg`:
```
agent = fence_ipmilan
ipaddr = 192.168.1.201
login = admin
passwd = secure_password
lanplus = 1
```

Repeat for other nodes with respective IP addresses.

### Step 2: Enable Fencing in Cluster

Edit `/etc/pve/corosync.conf` to add:

```
quorum {
    provider: corosync_votequorum
    expected_votes: 3
    two_node: 0
    wait_for_all: 0
    last_man_standing: 1
    last_man_standing_window: 10000
}
```

Apply changes:

```bash
# Restart corosync
systemctl restart corosync

# Verify fencing configuration
pvecm status
```

## Monitoring HA
Setting up proper monitoring for your HA environment:
```bash
# Create a simple monitoring script
cat > /usr/local/bin/ha-check.sh << 'EOF'
#!/bin/bash
HA_STATUS=$(ha-manager status | grep -v OK)
if [ ! -z "$HA_STATUS" ]; then
  echo "HA issues detected: $HA_STATUS"
  # Add notification commands here (email, etc.)
fi
EOF

chmod +x /usr/local/bin/ha-check.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/ha-check.sh") | crontab -
```

## 🔄 Recovery Procedures

### Handling a Split-Brain Situation

If cluster quorum is lost:

```bash
# On the node with most recent data
pvecm expected 1

# Force start services
ha-manager set vm:VMID --state started --force

# Once resolved, reset expected votes
pvecm expected 3
```

### Recovering a Failed Node

After fixing the node issues:

```bash
# On the recovered node
systemctl start pve-cluster corosync

# Verify node joined cluster
pvecm status
```

## 🛡️ Best Practices

1. **Regular Testing**: Schedule monthly tests of failover functionality
2. **Monitoring**: Implement external monitoring of cluster health
3. **Network Redundancy**: Use multiple network interfaces for cluster communication
4. **Power Protection**: Ensure all nodes have UPS protection
5. **Backup**: Maintain regular backups independent of HA functionality
6. **Documentation**: Keep configuration details and recovery procedures updated

## 📝 Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| VM won't migrate | Check if VM disks are on shared storage |
| Node won't join HA | Verify corosync and cluster services are running |
| Lost quorum | Use `pvecm expected` to force quorum |
| Migration fails | Check network connectivity and shared storage access |
| HA resource stuck | Use `ha-manager resource rm` then re-add |
