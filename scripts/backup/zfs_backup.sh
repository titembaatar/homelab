#!/bin/bash
set -e

# Parse config values
SCHEDULE_TYPE=$1
TIMESTAMP=$(date '+%y%m%d_%H%M%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"
LOG_DIR=$(yq -r '.log_dir' "$CONFIG_FILE")
LOG_FILE="${LOG_DIR}/${TIMESTAMP}_${SCHEDULE_TYPE}_backup.log"
BACKUP_DIR=$(yq -r '.backup_dir' "$CONFIG_FILE")
LOG_RETENTION=$(yq -r '.log_retention' "$CONFIG_FILE")
ENABLED_ENV=".backup_schedule.${SCHEDULE_TYPE}.enabled"
ENABLED=$(yq -r "$ENABLED_ENV" "$CONFIG_FILE")
RETENTION_ENV=".backup_schedule.${SCHEDULE_TYPE}.retention"
RETENTION=$(yq -r "$RETENTION_ENV" "$CONFIG_FILE")
DATASETS=$(yq  -r '.datasets[]' "$CONFIG_FILE")

# Log function
log() {
	if [ ! -f "$LOG_FILE" ]; then
		touch "$LOG_FILE"
	fi

  local type=${2:-INFO}
  local message=$1
  echo "[$(date '+%y%m%d')] [$(date '+%H%M%S')] [$type]: $message" >> "$LOG_FILE"
}

check_prerequisite() {
	# Get the schedule type
	if [ -z "$SCHEDULE_TYPE" ]; then
		log "Usage: $0 {hourly|daily|weekly|monthly|yearly}. Exiting..." "ERROR"
		exit 1
	fi

	# Check if config file exists
	if [ ! -f "$CONFIG_FILE" ]; then
		log "Config file not found: $CONFIG_FILE. Exiting..." "ERROR"
		exit 1
	fi

	# Check if yq is installed
	if ! command -v yq &> /dev/null; then
		log "yq is not installed. Please install yq to parse YAML files. Exiting..." "ERROR"
		exit 1
	fi
	
	# Check if schedule is enabled
	if [ "$ENABLED" != "true" ]; then
		log "$SCHEDULE_TYPE backups are disabled in the configuration" "INFO"
		log "Exiting script" "INFO"
		exit 0
	fi
}

check_dir_file() {
	# Create log directory if it doesn't exist
	if [ ! -d "$LOG_DIR" ]; then
		log "Creating log directory: $LOG_DIR" "INFO"
		mkdir -p "$LOG_DIR"
	fi

	# Check if backup directory exists
	if [ ! -d "$BACKUP_DIR" ]; then
		log "Creating backup directory: $BACKUP_DIR" "INFO"
		mkdir -p "$BACKUP_DIR"
	fi

	# Create schedule-specific backup directory
	if [ ! -d "$BACKUP_DIR/$SCHEDULE_TYPE" ]; then
		log "Creating backup directory: $BACKUP_DIR/$SCHEDULE_TYPE" "INFO"
		mkdir -p "$BACKUP_DIR/$SCHEDULE_TYPE"
	fi
}

backup_dataset() {
  log "Found $(echo "$DATASETS" | wc -l) datasets to backup" "INFO"
  for dataset in $DATASETS; do
    log "Backing up ZFS dataset: $dataset" "INFO"
    local snapshot_name="${dataset}@${TIMESTAMP}_backup"
    local backup_name="${BACKUP_DIR}/${SCHEDULE_TYPE}/${TIMESTAMP}_${dataset//\//_}.zfs"
    
    # Create new snapshot
    if ! zfs snapshot "$snapshot_name"; then
      log "ZFS dataset $dataset snapshot failed. Exiting..." "ERROR"
      exit 1
    fi
    
    # Perform full backup
    log "Performing full backup of $snapshot_name" "INFO"
    if ! zfs send "$snapshot_name" > "$backup_name"; then
      log "ZFS dataset $dataset send failed. Exiting..." "ERROR"
      exit 1
    fi
    
    # Clean up snapshot after successful backup
    if ! zfs destroy "$snapshot_name"; then
      log "Could not remove snapshot $snapshot_name" "WARN"
    fi
    
    log "ZFS dataset $dataset backup successful" "SUCCESS"
  done
}

remove_old_backup() {
  # Apply retention separately for each dataset
  for dataset in $DATASETS; do
    # The pattern needs to match files like: TIMESTAMP_dataset.zfs (e.g., 250318_070001_config_config.zfs)
    local dataset_file_pattern="${dataset//\//_}.zfs"
    log "Applying retention policy for dataset $dataset ($SCHEDULE_TYPE, keeping $RETENTION backups)" "INFO"
    
    # Find all backups for this specific dataset, sorted by timestamp (newest first)
    # IMPORTANT: Only look for files (-type f), never directories
    # The sort ensures newest backups are first (based on the YYMMDD_HHMMSS timestamp prefix)
    mapfile -t DATASET_BACKUPS < <(find "$BACKUP_DIR/$SCHEDULE_TYPE" \
      -maxdepth 1 -type f -name "*_${dataset_file_pattern}" | \
      sort -r)
      
    # Debug: Show what files were found for this dataset
    log "Files found for dataset $dataset:" "DEBUG"
    for file in "${DATASET_BACKUPS[@]}"; do
      log "  - $file" "DEBUG"
    done
    
    local files_count=${#DATASET_BACKUPS[@]}
    log "Found $files_count existing backups for dataset $dataset" "INFO"
    
    # Skip if we don't have more backups than the retention policy
    if [ "$files_count" -le "$RETENTION" ]; then
      log "No old backups need to be deleted for dataset $dataset (have $files_count, retention is $RETENTION)" "INFO"
      continue
    fi
    
    local to_keep=$RETENTION
    local to_delete=$((files_count - to_keep))
    log "Need to delete $to_delete old backups for dataset $dataset" "INFO"
    
    # Loop through the files to delete, starting from index that corresponds to files beyond retention
    for ((i=to_keep; i<files_count; i++)); do
      file="${DATASET_BACKUPS[$i]}"
      
      if [ -z "$file" ]; then
        log "Empty file entry detected at position $i, skipping" "WARN"
        continue
      fi
      
      # Extra safety check: make sure it's a file, not a directory
      if [ ! -f "$file" ]; then
        log "Not a regular file, skipping: $file" "WARN"
        continue
      fi
      
      log "Deleting old backup: $file" "INFO"
      
      # Use rm -f for files only, never rm -rf
      if ! rm -f "$file"; then
        log "Failed to delete: $file" "ERROR"
        continue
      fi
      
      log "Successfully deleted: $file" "SUCCESS"
    done
  done
}

remove_old_log() {
	log "Cleaning up old log files (keeping $LOG_RETENTION days)" "INFO"
	find "$LOG_DIR" -name "*.log" -type f -mtime +"$LOG_RETENTION" -exec rm -f {} \;
}

main() {
	check_prerequisite 
	check_dir_file

	log "Backup script started" "INFO"
	log "Schedule type: $SCHEDULE_TYPE" "INFO"

	backup_dataset 
	remove_old_backup
	remove_old_log

	log "$SCHEDULE_TYPE backup cycle completed successfully" "SUCCESS"
}

main
