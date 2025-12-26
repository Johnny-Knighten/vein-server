#!/usr/bin/env bash
set -euo pipefail

# Vein Server Runner - Starts and monitors the Vein game server

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Vein server..."

cd /vein-server/server || exit 1

# Check if server binary exists
if [[ ! -f "./VeinServer.sh" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] VeinServer.sh not found. Run updater first."
    exit 1
fi

# Start server
exec ./VeinServer.sh -log
