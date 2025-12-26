#!/usr/bin/env bash
set -euo pipefail

# System Bootstrap - PID 1 entrypoint for Vein server container
# Based on ark-sa-server architecture

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Vein server container..."

# Start supervisord
exec /usr/bin/supervisord -c /vein-server/supervisord/supervisord.conf
