#!/bin/bash
set -e

# Parse config values
schedule_type=$1
timestamp=$(date '+%y%m%d_%H%M%S')
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$script/config.yaml"
log_dir=$(yq -r '.log_dir' "$config_file")
log_file="${log_dir}/${timestamp}_${schedule_type}_backup.log"
backup_dir=$(yq -r '.backup_dir' "$config_file")
log_retention=$(yq -r '.log_retention' "$config_file")
enabled_env=".backup_schedule.${schedule_type}.enabled"
enabled=$(yq -r "$enabled_env" "$config_file")
retention_env=".backup_schedule.${schedule_type}.retention"
retention=$(yq -r "$retention_env" "$config_file")
datasets=$(yq  -r '.datasets[]' "$config_file")

log() {
	if [ ! -f "$log_file" ]; then
		touch "$log_file"
	fi

  local type=${2:-INFO}
  local message=$1
  echo "[$(date '+%y%m%d')] [$(date '+%H%M%S')] [$type]: $message" >> "$log_file"
}

check_prerequisite() {
	if [ -z "$schedule_type" ]; then
		log "Usage: $0 {hourly|daily|weekly|monthly|yearly}. Exiting..." "ERROR"
		exit 1
	fi

	if [ ! -f "$config_file" ]; then
		log "Config file not found: $config_file. Exiting..." "ERROR"
		exit 1
	fi

	if ! command -v yq &> /dev/null; then
		log "yq is not installed. Please install yq to parse YAML files. Exiting..." "ERROR"
		exit 1
	fi

	if [ "$enabled" != "true" ]; then
		log "$schedule_type backups are disabled in the configuration" "INFO"
		log "Exiting script" "INFO"
		exit 0
	fi
}

check_dir_file() {
	if [ ! -d "$log_dir" ]; then
		log "Creating log directory: $log_dir" "INFO"
		mkdir -p "$log_dir"
	fi

	if [ ! -d "$backup_dir" ]; then
		log "Creating backup directory: $backup_dir" "INFO"
		mkdir -p "$backup_dir"
	fi

	if [ ! -d "$backup_dir/$schedule_type" ]; then
		log "Creating backup directory: $backup_dir/$schedule_type" "INFO"
		mkdir -p "$backup_dir/$schedule_type"
	fi
}

backup_dataset() {
  log "Found $(echo "$datasets" | wc -l) datasets to backup" "INFO"
  for dataset in $datasets; do
    log "Backing up ZFS dataset: $dataset" "INFO"
    local snapshot_name="${dataset}@${timestamp}_backup"
    local backup_name="${backup_dir}/${schedule_type}/${timestamp}_${dataset//\//_}.zfs"

    if ! zfs snapshot "$snapshot_name"; then
      log "ZFS dataset $dataset snapshot failed. Exiting..." "ERROR"
      exit 1
    fi

    log "Performing full backup of $snapshot_name" "INFO"
    if ! zfs send "$snapshot_name" > "$backup_name"; then
      log "ZFS dataset $dataset send failed. Exiting..." "ERROR"
      exit 1
    fi

    if ! zfs destroy "$snapshot_name"; then
      log "Could not remove snapshot $snapshot_name" "WARN"
    fi

    log "ZFS dataset $dataset backup successful" "SUCCESS"
  done
}

remove_old_backup() {
  for dataset in $datasets; do
    local dataset_file_pattern="${dataset//\//_}.zfs"
    log "Applying retention policy for dataset $dataset ($schedule_type, keeping $retention backups)" "INFO"

    # IMPORTANT: Only look for files (-type f), never directories
    mapfile -t DATASET_BACKUPS < <(find "$backup_dir/$schedule_type" \
      -maxdepth 1 -type f -name "*_${dataset_file_pattern}" | \
      sort -r)

    # Debug
    log "Files found for dataset $dataset:" "DEBUG"
    for file in "${DATASET_BACKUPS[@]}"; do
      log "  - $file" "DEBUG"
    done

    local files_count=${#DATASET_BACKUPS[@]}
    log "Found $files_count existing backups for dataset $dataset" "INFO"

    if [ "$files_count" -le "$retention" ]; then
      log "No old backups need to be deleted for dataset $dataset (have $files_count, retention is $retention)" "INFO"
      continue
    fi

    local to_keep=$retention
    local to_delete=$((files_count - to_keep))
    log "Need to delete $to_delete old backups for dataset $dataset" "INFO"

    for ((i=to_keep; i<files_count; i++)); do
      file="${DATASET_BACKUPS[$i]}"

      if [ -z "$file" ]; then
        log "Empty file entry detected at position $i, skipping" "WARN"
        continue
      fi

      # Extra safety check
      if [ ! -f "$file" ]; then
        log "Not a regular file, skipping: $file" "WARN"
        continue
      fi

      log "Deleting old backup: $file" "INFO"

      if ! rm -f "$file"; then
        log "Failed to delete: $file" "ERROR"
        continue
      fi

      log "Successfully deleted: $file" "SUCCESS"
    done
  done
}

remove_old_log() {
	log "Cleaning up old log files (keeping $log_retention days)" "INFO"
	find "$log_dir" -name "*.log" -type f -mtime +"$log_retention" -exec rm -f {} \;
}

main() {
	check_prerequisite
	check_dir_file

	log "Backup script started" "INFO"
	log "Schedule type: $schedule_type" "INFO"

	backup_dataset
	remove_old_backup
	remove_old_log

	log "$schedule_type backup cycle completed successfully" "SUCCESS"
}

main
