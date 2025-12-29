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
    if [[ "$DRY_RUN" = "True" ]]; then
      echo "DRY_RUN - supervisorctl start vein-server"
    else
      supervisorctl start vein-server
    fi
  fi
}

start_vein_update() {
  if [[ "$SCRIPT_PARAM" = "update" ]]; then
    echo "Backup Process - Starting Vein Update After Backup"
    if [[ "$DRY_RUN" = "True" ]]; then
      echo "DRY_RUN - supervisorctl start vein-updater"
    else
      supervisorctl start vein-updater
    fi
  fi
}

zip_backup() {
  # Create zip of the contents of Saved (archive root is the contents, not the full absolute path)
  if [[ "$DRY_RUN" = "True" ]]; then
    echo "DRY_RUN - (cd \"${SERVER_DIR}/Vein/Saved\" && zip -r \"${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).zip\" .)"
  else
    (cd "${SERVER_DIR}/Vein/Saved" && zip -r "${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).zip" .)
  fi
}

tar_gz_backup() {
  # Create tar.gz of the contents of Saved (archive root is the contents, not the full absolute path)
  if [[ "$DRY_RUN" = "True" ]]; then
    echo "DRY_RUN - (cd \"${SERVER_DIR}/Vein/Saved\" && tar -czf \"${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).tar.gz\" .)"
  else
    (cd "${SERVER_DIR}/Vein/Saved" && tar -czf "${BACKUPS_DIR}/vein-server-$(date +%Y%m%d%H%M%S).tar.gz" .)
  fi
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
