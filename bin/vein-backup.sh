#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Backup Process - Starting"

SCRIPT_PARAM="$1"

main() {
  clean_up_backups_dir
  backup_vein_server
  start_vein_server
  start_vein_update
}

start_vein_server() {
  if [[ "$SCRIPT_PARAM" = "restart" ]]; then
    echo "Backup Process - Starting Vein Server After Backup"
    wait_before_server_start
    supervisorctl start vein-server
  fi
}

wait_before_server_start() {
  local delay="${SERVER_RESTART_DELAY:-20}"
  if [[ "$delay" -gt 0 ]]; then
    echo "Backup Process - Waiting ${delay}s Before Starting Server (SERVER_RESTART_DELAY)"
    sleep "$delay"
  fi
}

start_vein_update() {
  if [[ "$SCRIPT_PARAM" = "update" ]]; then
    echo "Backup Process - Starting Vein Update After Backup"
    supervisorctl start vein-updater
  fi
}

zip_backup() {
  # Create zip of the contents of Saved (archive root is the contents, not the full absolute path)
  (cd "${SERVER_DIR}/Vein/Saved" && zip -r "${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).zip" .)
}

tar_gz_backup() {
  # Create tar.gz of the contents of Saved (archive root is the contents, not the full absolute path)
  (cd "${SERVER_DIR}/Vein/Saved" && tar -czf "${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).tar.gz" .)
}

backup_vein_server() {
  echo "Backup Process - Backing Up Vein Server"
  if [[ "$ZIP_BACKUPS" = "True" ]]; then
    zip_backup
  else
    tar_gz_backup
  fi
  echo "Backup Process - Backup Finished"
}

clean_up_backups_dir() {
  if [[ -n "$RETAIN_BACKUPS" ]]; then
    echo "Backup Process - Cleaning Up Backup Directory"
    count_files() {
      find "$BACKUPS_DIR" -type f | wc -l
    }

    delete_oldest_file() {
      find "$BACKUPS_DIR" -type f -print0 | xargs -0 ls -tr | head -n 1 | xargs rm -f
    }

    current_file_count=$(count_files)

    while [ "$current_file_count" -gt "$((RETAIN_BACKUPS - 1))" ]; do
      echo "Backup Process - File Limit Exceeded: ($current_file_count), Deleting Oldest"
      delete_oldest_file
      current_file_count=$(count_files)
    done

    echo "Backup Process - File Count Post Cleanup: $(count_files)"
  fi
}

main
