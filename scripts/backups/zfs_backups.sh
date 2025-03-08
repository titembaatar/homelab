#!/bin/bash
# Proxmox ZFS Backup Script

# Configuration
FULL_POOL="config"  # Your pool for full backup
PHOTO_DATASET="vault/subvol-0-disk-0/immich" # Your photo dataset
BACKUP_MOUNT="/mnt/pve/backups" # Proxmox storage mount point
CREDS_FILE="/root/.smbcreds" # SMB credentials file
RETENTION=5               # Number of backups to keep for each type
LOG_FILE="/var/log/zfs-backup.log"

# Logging function
log() {
  local level=$1 message=$2 timestamp
  timestamp=$(date "+%y%m%d.%H:%M:%S")
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
  # Check if credentials file exists if needed (only if we need to mount manually)
  if ! mount | grep -q "$BACKUP_MOUNT"; then
    if [ ! -f "$CREDS_FILE" ]; then
      log "ERROR" "SMB credentials file not found at $CREDS_FILE"
      log "INFO" "Please create it with the following content:"
      log "INFO" "username=your_username"
      log "INFO" "password=your_password"
      log "INFO" "Then set permissions with: chmod 600 $CREDS_FILE"
      return 1
    fi
  fi

  # Check backup mount exists
  if [ ! -d "$BACKUP_MOUNT" ]; then
    log "ERROR" "Backup mount point $BACKUP_MOUNT does not exist"
    return 1
  fi

  # Check if backup mount is accessible
  if [ ! -w "$BACKUP_MOUNT" ]; then
    log "ERROR" "Backup mount point $BACKUP_MOUNT is not writable"
    return 1
  fi

  return 0
}

# Create backup directories
create_backup_dirs() {
  mkdir -p "$BACKUP_MOUNT/zfs_backups/daily"
  mkdir -p "$BACKUP_MOUNT/zfs_backups/weekly"
  mkdir -p "$BACKUP_MOUNT/zfs_backups/monthly"
  mkdir -p "$BACKUP_MOUNT/zfs_backups/logs"
  
  log "INFO" "Created backup directories"
}

# Determine backup type
determine_backup_type() {
  DAY_OF_WEEK=$(date +%u)
  DAY_OF_MONTH=$(date +%d)
  DATE_SUFFIX=$(date +%y%m%d)

  if [ "$DAY_OF_MONTH" = "01" ]; then
    BACKUP_TYPE="monthly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/monthly"
  elif [ "$DAY_OF_WEEK" = "7" ]; then
    BACKUP_TYPE="weekly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/weekly"
  else
    BACKUP_TYPE="daily"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/daily"
  fi

  SNAPSHOT_NAME="${BACKUP_TYPE}_${DATE_SUFFIX}"
  
  log "INFO" "Determined backup type: $BACKUP_TYPE"
}

# Backup ZFS pool
backup_zfs_pool() {
  local pool=$1 is_recursive=$2
  
  log "INFO" "Creating snapshot of $pool@$SNAPSHOT_NAME"
  
  if [ "$is_recursive" = "true" ]; then
    if ! zfs snapshot -r "$pool@$SNAPSHOT_NAME"; then
      log "ERROR" "Failed to create recursive snapshot of $pool"
      return 1
    fi
    
    log "INFO" "Sending $pool backup to $BACKUP_DIR"
    
    if ! zfs send -R "$pool@$SNAPSHOT_NAME" | gzip > "$BACKUP_DIR/${pool}_${SNAPSHOT_NAME}.zfs.gz"; then
      log "ERROR" "Failed to send backup of $pool"
      return 1
    fi
  else
    if ! zfs snapshot "$pool@$SNAPSHOT_NAME"; then
      log "ERROR" "Failed to create snapshot of $pool"
      return 1
    fi
    
    log "INFO" "Sending $pool backup to $BACKUP_DIR"
    
    if ! zfs send "$pool@$SNAPSHOT_NAME" | gzip > "$BACKUP_DIR/${pool//\//_}_${SNAPSHOT_NAME}.zfs.gz"; then
      log "ERROR" "Failed to send backup of $pool"
      return 1
    fi
  fi
  
  log "INFO" "Successfully backed up $pool"
  return 0
}

# Clean old backups
clean_old_backups() {
  local backup_dir=$1 keep=$2
  
  log "INFO" "Cleaning old backups in $backup_dir, keeping $keep"
  
  # List files by modification time, keep the newest $keep files
  if [ -d "$backup_dir" ]; then
    if ! find "$backup_dir" -name "*.zfs.gz" -type f -printf "%T@ %p\n" | \
      sort -rn | \
      tail -n +$((keep + 1)) | \
      cut -d' ' -f2- | \
      xargs -r rm; then

      log "WARN" "Some issues occurred while cleaning old backups in $backup_dir"
    fi
  else
    log "WARN" "Backup directory $backup_dir does not exist"
  fi
}

# Clean old snapshots
clean_old_snapshots() {
  local pool=$1 keep=$2
  
  log "INFO" "Cleaning old snapshots for $pool, keeping $keep of each type"
  
  # Clean daily snapshots
  zfs_snapshots_daily=$(zfs list -H -o name -t snapshot | grep "$pool@daily_" | sort)
  if [ -n "$zfs_snapshots_daily" ]; then
    if ! echo "$zfs_snapshots_daily" | head -n -"$keep" | xargs -r zfs destroy; then
      log "WARN" "Issues occurred while cleaning daily snapshots for $pool"
    fi
  fi
  
  # Clean weekly snapshots
  zfs_snapshots_weekly=$(zfs list -H -o name -t snapshot | grep "$pool@weekly_" | sort)
  if [ -n "$zfs_snapshots_weekly" ]; then
    if ! echo "$zfs_snapshots_weekly" | head -n -"$keep" | xargs -r zfs destroy; then
      log "WARN" "Issues occurred while cleaning weekly snapshots for $pool"
    fi
  fi
  
  # Clean monthly snapshots
  zfs_snapshots_monthly=$(zfs list -H -o name -t snapshot | grep "$pool@monthly_" | sort)
  if [ -n "$zfs_snapshots_monthly" ]; then
    if ! echo "$zfs_snapshots_monthly" | head -n -"$keep" | xargs -r zfs destroy; then
      log "WARN" "Issues occurred while cleaning monthly snapshots for $pool"
    fi
  fi
}

export_log() {
  local log_timestamp
  log_timestamp=$(date "+%y%m%d_%H%M%S")
  log "INFO" "Exporting logs to '$BACKUP_MOUNT/zfs_backups/logs'"
  
  # Copy log file with timestamp to prevent overwriting
  cp "$LOG_FILE" "$BACKUP_MOUNT/zfs_backups/logs/zfs-backup_${log_timestamp}.log"
  
  # Keep only the most recent 20 log files
  find "$BACKUP_MOUNT/zfs_backups/logs" -name "zfs-backup_*.log" -type f -printf "%T@ %p\n" | \
    sort -rn | \
    tail -n +21 | \
    cut -d' ' -f2- | \
    xargs -r rm
}

# Main function
main() {
  log "INFO" "Starting ZFS backup process"
  
  # Check prerequisites
  if ! check_prerequisites; then
    log "ERROR" "Failed prerequisite check, exiting"
    return 1
  fi
  
  # Create backup directories
  create_backup_dirs
  
  # Determine backup type
  determine_backup_type
  
  # Backup entire ZFS pool (config)
  if ! backup_zfs_pool "$FULL_POOL" "true"; then
    log "ERROR" "Failed to backup $FULL_POOL"
  fi
  
  # Backup photos dataset only
  if ! backup_zfs_pool "$PHOTO_DATASET" "false"; then
    log "ERROR" "Failed to backup $PHOTO_DATASET"
  fi
  
  # Clean up old backups to maintain retention policy
  clean_old_backups "$BACKUP_MOUNT/zfs_backups/daily" "$RETENTION"
  clean_old_backups "$BACKUP_MOUNT/zfs_backups/weekly" "$RETENTION"
  clean_old_backups "$BACKUP_MOUNT/zfs_backups/monthly" "$RETENTION"
  
  # Clean up old snapshots
  clean_old_snapshots "$FULL_POOL" "$RETENTION"
  clean_old_snapshots "$PHOTO_DATASET" "$RETENTION"

  # Export log to backups smb share
  export_log
  
  log "INFO" "Backup completed successfully"
  return 0
}

# Execute main function
main
exit $?
