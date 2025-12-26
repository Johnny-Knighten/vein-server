#!/usr/bin/env bash
set -euo pipefail

# Vein Bootstrap - Initial setup and directory creation

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Running Vein bootstrap..."

# Create required directories
mkdir -p /vein-server/server
mkdir -p /vein-server/logs
mkdir -p /vein-server/backups

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Bootstrap complete"

# Start the server
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting vein-server..."
supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-server
