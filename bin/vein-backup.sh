#!/usr/bin/env bash
set -euo pipefail

# Vein Backup - Creates backup of server data

TIMESTAMP=$(date '+%Y-%m-%d-%H-%M-%S')
BACKUP_FILE="/vein-server/backups/vein-backup-${TIMESTAMP}.tar.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating backup: ${BACKUP_FILE}"

# Backup the Saved directory (contains save files and configs)
tar -czf "${BACKUP_FILE}" -C /vein-server/server/Vein Saved 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Backup complete"
