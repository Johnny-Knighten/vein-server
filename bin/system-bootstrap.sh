#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "System Bootstrap - Starting"

cleanup() {
  echo "System Bootstrap - Cleanup Starting"
  supervisorctl stop all

  if [[ "$BACKUP_ON_STOP" = "True" ]]; then
    echo "System Bootstrap - BACKUP_ON_STOP Enabled, Starting Backup"
    supervisorctl start vein-backup
    wait_for_backup_completion
  else
    echo "System Bootstrap - BACKUP_ON_STOP Disabled, Skipping Backup"
  fi

  supervisorctl exit
  echo "System Bootstrap - Cleanup Stopping"
}

main() {
  setup_cron_jobs
  trap 'cleanup' SIGTERM
  /usr/bin/supervisord -c /vein-server/supervisord/supervisord.conf &
  wait $!
}

setup_cron_jobs() {
  if [[ "$SCHEDULED_RESTART" = "True" ]]; then
    if [[ "$BACKUP_ON_SCHEDULED_RESTART" = "True" ]]; then
      echo "System Bootstrap - Setting Up Scheduled Restart With Backup"
      setup_cron_scheduled_restart_with_backup >> /usr/local/bin/vein-cron-jobs
    else
      echo "System Bootstrap - Setting Up Scheduled Restart"
      setup_cron_scheduled_restart >> /usr/local/bin/vein-cron-jobs
    fi
  fi

  if [[ "$SCHEDULED_UPDATE" = "True" ]]; then
    if [[ "$BACKUP_BEFORE_UPDATE" = "True" ]]; then
      echo "System Bootstrap - Setting Up Scheduled Update With Backup"
      setup_cron_scheduled_update_with_backup >> /usr/local/bin/vein-cron-jobs
    else
      echo "System Bootstrap - Setting Up Scheduled Update"
      setup_cron_scheduled_update >> /usr/local/bin/vein-cron-jobs
    fi
  fi

  if [[ "$SCHEDULED_BACKUP" = "True" ]]; then
    echo "System Bootstrap - Setting Up Scheduled Backup"
    setup_cron_scheduled_backup >> /usr/local/bin/vein-cron-jobs
  fi

  if [[ -f /usr/local/bin/vein-cron-jobs ]]; then
    echo "System Bootstrap - Updating Crontab"
    crontab /usr/local/bin/vein-cron-jobs
    rm /usr/local/bin/vein-cron-jobs
  fi
}

setup_cron_scheduled_restart() {
  local delay="${SERVER_RESTART_DELAY:-20}"
  echo "$(date) - Server Restart CRON Scheduled For: $RESTART_CRON" >> /vein-server/logs/cron.log
  echo "$RESTART_CRON supervisorctl stop vein-server && sleep $delay && supervisorctl start vein-server && \
    echo \"\$(date) - CRON Restart - vein-server\" >> /vein-server/logs/cron.log"
}

setup_cron_scheduled_restart_with_backup() {
  echo "$(date) - Server Restart and Backup CRON Scheduled For: $RESTART_CRON" >> /vein-server/logs/cron.log
  echo "$RESTART_CRON supervisorctl stop vein-server && supervisorctl start vein-backup-and-restart && \
    echo \"\$(date) - CRON Restart + Backup - vein-server\" >> /vein-server/logs/cron.log"
}

setup_cron_scheduled_update() {
  echo "$(date) - Server Update Scheduled For: $UPDATE_CRON" >> /vein-server/logs/cron.log
  echo "$UPDATE_CRON supervisorctl stop vein-server && supervisorctl start vein-updater && \
    echo \"\$(date) - CRON Update - vein-updater\" >> /vein-server/logs/cron.log"
}

setup_cron_scheduled_update_with_backup() {
  echo "$(date) - Server Update and Backup Scheduled For: $UPDATE_CRON" >> /vein-server/logs/cron.log
  echo "$UPDATE_CRON supervisorctl stop vein-server && supervisorctl start vein-backup-and-update && \
    echo \"\$(date) - CRON Update + Backup - vein-updater\" >> /vein-server/logs/cron.log"
}

setup_cron_scheduled_backup() {
  echo "$(date) - Server Backup Scheduled For: $BACKUP_CRON" >> /vein-server/logs/cron.log
  echo "$BACKUP_CRON supervisorctl stop vein-server && supervisorctl start vein-backup-and-restart && \
    echo \"\$(date) - CRON Backup - vein-backup\" >> /vein-server/logs/cron.log"
}

wait_for_backup_completion() {
  local counter=0
  local max_wait_time=600

  while true; do
    local status
    status=$(supervisorctl status vein-backup)
    if [[ "$status" == *"RUNNING"* ]] || [[ "$status" == *"STARTING"* ]]; then
      echo "System Bootstrap - Waiting For Backup Process To Finish."
    elif [[ "$status" == *"STOPPED"* ]] || [[ "$status" == *"EXITED"* ]] || [[ "$status" == *"FATAL"* ]]; then
      echo "System Bootstrap - Backup Process Has Finished"
      break
    fi

    sleep 5
    ((counter += 5))

    if [[ "$counter" -ge "$max_wait_time" ]]; then
      echo "System Bootstrap - Timeout Duration Exceeded, Closing Supervisor Without Complete Backup"
      break
    fi
  done
}

main
