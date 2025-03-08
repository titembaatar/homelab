#!/bin/bash
# Proxmox ZFS Backup Script with Configuration File Support

# Default configuration file path
CONFIG_FILE="./zfs_backups.yml"

# Check if config file is specified as argument
if [ "$1" != "" ]; then
  CONFIG_FILE="$1"
fi

# Check if yq is installed
check_yq() {
  if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install it to parse YAML."
    echo "On Debian/Ubuntu: apt-get install yq"
    echo "Or download from: https://github.com/mikefarah/yq/releases"
    exit 1
  fi
}

# Parse YAML configuration
parse_config() {
  check_yq
  
  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
  fi
  
  # Parse configuration
  BACKUP_MOUNT=$(yq eval '.backup_mount' "$CONFIG_FILE")
  CREDS_FILE=$(yq eval '.creds_file' "$CONFIG_FILE")
  RETENTION=$(yq eval '.retention' "$CONFIG_FILE")
  LOG_FILE=$(yq eval '.log_file' "$CONFIG_FILE")
  
  # Create log file if it doesn't exist
  touch "$LOG_FILE"
  
  log "INFO" "Using configuration file: $CONFIG_FILE"
}

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
  # Create standard directories
  mkdir -p "$BACKUP_MOUNT/zfs_backups/logs"
  
  # Create directories based on enabled backup types
  if [ "$(yq eval '.backup_schedule.hourly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    mkdir -p "$BACKUP_MOUNT/zfs_backups/hourly"
  fi
  
  if [ "$(yq eval '.backup_schedule.daily.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    mkdir -p "$BACKUP_MOUNT/zfs_backups/daily"
  fi
  
  if [ "$(yq eval '.backup_schedule.weekly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    mkdir -p "$BACKUP_MOUNT/zfs_backups/weekly"
  fi
  
  if [ "$(yq eval '.backup_schedule.monthly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    mkdir -p "$BACKUP_MOUNT/zfs_backups/monthly"
  fi
  
  if [ "$(yq eval '.backup_schedule.yearly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    mkdir -p "$BACKUP_MOUNT/zfs_backups/yearly"
  fi
  
  log "INFO" "Created backup directories"
}

# Determine backup type
determine_backup_type() {
  # Get enabled backup types from config
  ENABLE_HOURLY=$(yq eval '.backup_schedule.hourly.enabled // false' "$CONFIG_FILE")
  ENABLE_DAILY=$(yq eval '.backup_schedule.daily.enabled // true' "$CONFIG_FILE")
  ENABLE_WEEKLY=$(yq eval '.backup_schedule.weekly.enabled // true' "$CONFIG_FILE")
  ENABLE_MONTHLY=$(yq eval '.backup_schedule.monthly.enabled // true' "$CONFIG_FILE")
  ENABLE_YEARLY=$(yq eval '.backup_schedule.yearly.enabled // false' "$CONFIG_FILE")
  
  # Get time values
  HOUR=$(date +%H)
  DAY_OF_WEEK=$(date +%u)
  DAY_OF_MONTH=$(date +%d)
  MONTH=$(date +%m)
  DATE_SUFFIX=$(date +%y%m%d_%H%M%S)
  
  # Get configured values from config
  if [ "$ENABLE_WEEKLY" = "true" ]; then
    WEEKLY_DAY=$(yq eval '.backup_schedule.weekly.day // 7' "$CONFIG_FILE")
  else
    WEEKLY_DAY=7
  fi
  
  if [ "$ENABLE_MONTHLY" = "true" ]; then
    MONTHLY_DAY=$(yq eval '.backup_schedule.monthly.day // 1' "$CONFIG_FILE")
  else
    MONTHLY_DAY=1
  fi
  
  if [ "$ENABLE_YEARLY" = "true" ]; then
    YEARLY_MONTH=$(yq eval '.backup_schedule.yearly.month // 1' "$CONFIG_FILE")
    YEARLY_DAY=$(yq eval '.backup_schedule.yearly.day // 1' "$CONFIG_FILE")
  else
    YEARLY_MONTH=1
    YEARLY_DAY=1
  fi
  
  # Determine backup type based on date/time and configuration
  if [ "$ENABLE_YEARLY" = "true" ] && [ "$MONTH" = "$YEARLY_MONTH" ] && [ "$DAY_OF_MONTH" = "$YEARLY_DAY" ]; then
    BACKUP_TYPE="yearly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/yearly"
  elif [ "$ENABLE_MONTHLY" = "true" ] && [ "$DAY_OF_MONTH" = "$MONTHLY_DAY" ]; then
    BACKUP_TYPE="monthly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/monthly"
  elif [ "$ENABLE_WEEKLY" = "true" ] && [ "$DAY_OF_WEEK" = "$WEEKLY_DAY" ]; then
    BACKUP_TYPE="weekly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/weekly"
  elif [ "$ENABLE_DAILY" = "true" ]; then
    BACKUP_TYPE="daily"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/daily"
  elif [ "$ENABLE_HOURLY" = "true" ]; then
    BACKUP_TYPE="hourly"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/hourly"
  else
    # Fallback to daily if nothing is enabled
    BACKUP_TYPE="daily"
    BACKUP_DIR="$BACKUP_MOUNT/zfs_backups/daily"
    log "WARN" "No backup type is enabled in config, defaulting to daily"
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
  
  # Clean hourly snapshots if enabled
  if [ "$(yq eval '.backup_schedule.hourly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    HOURLY_RETENTION=$(yq eval '.backup_schedule.hourly.retention // '"$keep"'' "$CONFIG_FILE")
    zfs_snapshots_hourly=$(zfs list -H -o name -t snapshot | grep "$pool@hourly_" | sort)
    if [ -n "$zfs_snapshots_hourly" ]; then
      if ! echo "$zfs_snapshots_hourly" | head -n -"$HOURLY_RETENTION" | xargs -r zfs destroy; then
        log "WARN" "Issues occurred while cleaning hourly snapshots for $pool"
      fi
    fi
  fi
  
  # Clean daily snapshots if enabled
  if [ "$(yq eval '.backup_schedule.daily.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    DAILY_RETENTION=$(yq eval '.backup_schedule.daily.retention // '"$keep"'' "$CONFIG_FILE")
    zfs_snapshots_daily=$(zfs list -H -o name -t snapshot | grep "$pool@daily_" | sort)
    if [ -n "$zfs_snapshots_daily" ]; then
      if ! echo "$zfs_snapshots_daily" | head -n -"$DAILY_RETENTION" | xargs -r zfs destroy; then
        log "WARN" "Issues occurred while cleaning daily snapshots for $pool"
      fi
    fi
  fi
  
  # Clean weekly snapshots if enabled
  if [ "$(yq eval '.backup_schedule.weekly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    WEEKLY_RETENTION=$(yq eval '.backup_schedule.weekly.retention // '"$keep"'' "$CONFIG_FILE")
    zfs_snapshots_weekly=$(zfs list -H -o name -t snapshot | grep "$pool@weekly_" | sort)
    if [ -n "$zfs_snapshots_weekly" ]; then
      if ! echo "$zfs_snapshots_weekly" | head -n -"$WEEKLY_RETENTION" | xargs -r zfs destroy; then
        log "WARN" "Issues occurred while cleaning weekly snapshots for $pool"
      fi
    fi
  fi
  
  # Clean monthly snapshots if enabled
  if [ "$(yq eval '.backup_schedule.monthly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    MONTHLY_RETENTION=$(yq eval '.backup_schedule.monthly.retention // '"$keep"'' "$CONFIG_FILE")
    zfs_snapshots_monthly=$(zfs list -H -o name -t snapshot | grep "$pool@monthly_" | sort)
    if [ -n "$zfs_snapshots_monthly" ]; then
      if ! echo "$zfs_snapshots_monthly" | head -n -"$MONTHLY_RETENTION" | xargs -r zfs destroy; then
        log "WARN" "Issues occurred while cleaning monthly snapshots for $pool"
      fi
    fi
  fi
  
  # Clean yearly snapshots if enabled
  if [ "$(yq eval '.backup_schedule.yearly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    YEARLY_RETENTION=$(yq eval '.backup_schedule.yearly.retention // '"$keep"'' "$CONFIG_FILE")
    zfs_snapshots_yearly=$(zfs list -H -o name -t snapshot | grep "$pool@yearly_" | sort)
    if [ -n "$zfs_snapshots_yearly" ]; then
      if ! echo "$zfs_snapshots_yearly" | head -n -"$YEARLY_RETENTION" | xargs -r zfs destroy; then
        log "WARN" "Issues occurred while cleaning yearly snapshots for $pool"
      fi
    fi
  fi
}

export_log() {
  # Check if log export is enabled
  EXPORT_LOGS=$(yq eval '.export_logs // true' "$CONFIG_FILE")
  
  if [ "$EXPORT_LOGS" = "true" ]; then
    local log_timestamp
    log_timestamp=$(date "+%y%m%d_%H%M%S")
    log "INFO" "Exporting logs to '$BACKUP_MOUNT/zfs_backups/logs'"
    
    # Copy log file with timestamp to prevent overwriting
    cp "$LOG_FILE" "$BACKUP_MOUNT/zfs_backups/logs/zfs_backups_${log_timestamp}.log"
    
    # Get log retention count, default to 20
    LOG_RETENTION=$(yq eval '.log_retention // 20' "$CONFIG_FILE")
    
    # Keep only the most recent LOG_RETENTION log files
    find "$BACKUP_MOUNT/zfs_backups/logs" -name "zfs_backup_*.log" -type f -printf "%T@ %p\n" | \
      sort -rn | \
      tail -n +"$((LOG_RETENTION + 1))" | \
      cut -d' ' -f2- | \
      xargs -r rm
  else
    log "INFO" "Log export disabled in configuration"
  fi
}

# Process pools and datasets from configuration
process_backups() {
  # Get number of full pools (recursive backups)
  FULL_POOLS_COUNT=$(yq eval '.full_pools | length' "$CONFIG_FILE")
  
  # Process each full pool
  if [ "$FULL_POOLS_COUNT" -gt 0 ]; then
    for i in $(seq 0 $((FULL_POOLS_COUNT - 1))); do
      POOL=$(yq eval ".full_pools[$i]" "$CONFIG_FILE")
      log "INFO" "Processing full pool: $POOL"
      
      if ! backup_zfs_pool "$POOL" "true"; then
        log "ERROR" "Failed to backup full pool $POOL"
      fi
      
      # Clean up old snapshots for this pool
      clean_old_snapshots "$POOL" "$RETENTION"
    done
  fi
  
  # Get number of individual datasets
  DATASETS_COUNT=$(yq eval '.datasets | length' "$CONFIG_FILE")
  
  # Process each dataset
  if [ "$DATASETS_COUNT" -gt 0 ]; then
    for i in $(seq 0 $((DATASETS_COUNT - 1))); do
      DATASET=$(yq eval ".datasets[$i]" "$CONFIG_FILE")
      log "INFO" "Processing dataset: $DATASET"
      
      if ! backup_zfs_pool "$DATASET" "false"; then
        log "ERROR" "Failed to backup dataset $DATASET"
      fi
      
      # Clean up old snapshots for this dataset
      clean_old_snapshots "$DATASET" "$RETENTION"
    done
  fi
}

# Main function
main() {
  log "INFO" "Starting ZFS backup process"
  
  # Parse configuration
  parse_config
  
  # Check prerequisites
  if ! check_prerequisites; then
    log "ERROR" "Failed prerequisite check, exiting"
    return 1
  fi
  
  # Create backup directories
  create_backup_dirs
  
  # Determine backup type
  determine_backup_type
  
  # Process backups based on configuration
  process_backups
  
  # Clean up old backups to maintain retention policy
  if [ "$(yq eval '.backup_schedule.hourly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    HOURLY_RETENTION=$(yq eval '.backup_schedule.hourly.retention // '"$RETENTION"'' "$CONFIG_FILE")
    clean_old_backups "$BACKUP_MOUNT/zfs_backups/hourly" "$HOURLY_RETENTION"
  fi
  
  if [ "$(yq eval '.backup_schedule.daily.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    DAILY_RETENTION=$(yq eval '.backup_schedule.daily.retention // '"$RETENTION"'' "$CONFIG_FILE")
    clean_old_backups "$BACKUP_MOUNT/zfs_backups/daily" "$DAILY_RETENTION"
  fi
  
  if [ "$(yq eval '.backup_schedule.weekly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    WEEKLY_RETENTION=$(yq eval '.backup_schedule.weekly.retention // '"$RETENTION"'' "$CONFIG_FILE")
    clean_old_backups "$BACKUP_MOUNT/zfs_backups/weekly" "$WEEKLY_RETENTION"
  fi
  
  if [ "$(yq eval '.backup_schedule.monthly.enabled // true' "$CONFIG_FILE")" = "true" ]; then
    MONTHLY_RETENTION=$(yq eval '.backup_schedule.monthly.retention // '"$RETENTION"'' "$CONFIG_FILE")
    clean_old_backups "$BACKUP_MOUNT/zfs_backups/monthly" "$MONTHLY_RETENTION"
  fi
  
  if [ "$(yq eval '.backup_schedule.yearly.enabled // false' "$CONFIG_FILE")" = "true" ]; then
    YEARLY_RETENTION=$(yq eval '.backup_schedule.yearly.retention // '"$RETENTION"'' "$CONFIG_FILE")
    clean_old_backups "$BACKUP_MOUNT/zfs_backups/yearly" "$YEARLY_RETENTION"
  fi
  
  # Export log to backups share
  export_log
  
  log "INFO" "Backup completed successfully"
  return 0
}

# Execute main function
main
exit $?
