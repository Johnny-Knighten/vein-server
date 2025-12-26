#!/usr/bin/env bash
set -euo pipefail

# System Bootstrap - PID 1 entrypoint for Vein server container
# Based on ark-sa-server architecture

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Vein server container..."

# Graceful shutdown handler
shutdown() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Shutdown signal received, stopping services..."
    supervisorctl -c /vein-server/supervisord/supervisord.conf shutdown
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Start supervisord
exec /usr/bin/supervisord -c /vein-server/supervisord/supervisord.conf
