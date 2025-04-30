# 🖥️ Proxmox Cluster

## Cluster Creation

### Step 1: Create the Cluster (`Khuleg_Baatar`)
Run these commands on the first node (`Mukhulai`):
```bash
pvecm create Khuleg_Baatar
pvecm status
```

### Step 2: Add Second Node (`Borchi`)
Run these commands on the second node (`Borchi`):
```bash
pvecm add Mukhulai.local --fingerprint XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

### Step 3: Add Third Node (`Borokhul`)
Run these commands on the third node (`Borokhul`):
```bash
pvecm add Mukhulai.local --fingerprint XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

## Verify Cluster Status
Run on any node:
```bash
# Check cluster status
pvecm status
# List nodes
pvecm nodes
```
