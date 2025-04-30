# 📥 Backup Strategy

## ZFS Backup Script
The `zfs_backup.sh` script provides an automated solution for backing up ZFS datasets with configurable retention policies.

> [!WARNING]
>
> The script prioritizes safety and simplicity by performing full backups for each dataset.
> While this consumes more storage space than incremental backups,
> it ensures that each backup is completely independent and can be restored without dependencies on other backups.

### How It Works
The backup process follows these steps:
1. Reads configuration from `config.yml`
2. Creates a ZFS snapshot for each datasets
3. Performs a full send of the snapshot to the backup location
4. Deletes the snapshot on the source system
5. Applies retention policies to clean up old backups
6. Maintains logs with configurable retention

## Configuration

### Configuration File Structure
All backup settings are managed through the `config.yml` file:
```yaml
backup_dir: /mnt/pve/borte/zfs_backup
log_dir: /mnt/pve/borte/zfs_backup/log
log_retention: 32

backup_schedule:
  hourly:
    enabled: false
    retention: 24
  daily:
    enabled: true
    retention: 7
  weekly:
    enabled: true
    retention: 4
  monthly:
    enabled: true
    retention: 12
  yearly:
    enabled: true
    retention: 2

datasets:
  - "vault/khulan"
  - "flash/yesugen"
  - "flash/yesui"
```

### Key Configuration Options
- `backup_dir`: Location where backups are stored
- `log_dir`: Location for backup logs
- `log_retention`: Number log files to keep
- `backup_schedule`: Defines which schedules are enabled and their retention periods
- `datasets`: List of ZFS datasets to back up

## Scheduling with Crontab

### Recommended Crontab Configuration
Set up automated backups using crontab with staggered start times to prevent overlaps:
```
0 2 * * * /path/to/zfs_backup.sh daily
0 3 * * 7 /path/to/zfs_backup.sh weekly
0 4 1 * * /path/to/zfs_backup.sh monthly
0 5 1 1 * /path/to/zfs_backup.sh yearly
```

This configuration:
- Runs daily backups at 2:00 AM every day
- Runs weekly backups at 3:00 AM every Sunday
- Runs monthly backups at 4:00 AM on the 1st day of each month
- Runs yearly backups at 5:00 AM on January 1st

To add these entries to your crontab:
```bash
crontab -e
```

## Backup Storage Structure
The backup script organizes backups in this structure:
```
/mnt/pve/borte/zfs_backup/
├── daily/
│   ├── 240313_020000_flash_yesugen.zfs
│   ├── 240313_020000_flash_yesui.zfs
│   ├── 240313_020000_vault_khulan.zfs
│   └── ...
├── weekly/
│   ├── 240310_030000_flash_yesugen.zfs
│   ├── 240310_030000_flash_yesui.zfs
│   ├── 240310_030000_vault_khulan.zfs
│   └── ...
├── monthly/
│   └── ...
├── yearly/
│   └── ...
└── log/
    ├── 240313_020000_daily_backup.log
    └── ...
```

## Restoration Process
To restore a dataset from backup:
```bash
# Restore a dataset from a full backup
zfs receive tank/newdataset < /mnt/pve/borte/zfs_backup/daily/240313_020000_flash_yesui.zfs
```

## Maintenance Tasks

### Regular Verification
Periodically verify your backups:
```bash
# List all backups
find /mnt/pve/borte/zfs_backup -name "*.zfs" | sort

# Check backup integrity (reads through the backup file)
zfs receive -n tank/test < /mnt/pve/borte/zfs_backup/daily/240313_020000_flash_yesui.zfs
```
