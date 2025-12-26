#!/usr/bin/env bash
set -euo pipefail

# Vein Bootstrap - Initial setup, directory creation, and FSM state routing

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Running Vein bootstrap..."

# Create required directories
mkdir -p /vein-server/server
mkdir -p /vein-server/logs
mkdir -p /vein-server/backups

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Directory setup complete"

# Environment variables with defaults
VEIN_AUTO_UPDATE="${VEIN_AUTO_UPDATE:-true}"
VEIN_UPDATE_ON_START="${VEIN_UPDATE_ON_START:-true}"

# Determine if this is first run (no VeinServer.sh exists)
FIRST_RUN=false
if [[ ! -f "/vein-server/server/VeinServer.sh" ]]; then
    FIRST_RUN=true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] First run detected (VeinServer.sh not found)"
fi

# FSM State Routing Logic
if [[ "${VEIN_AUTO_UPDATE}" == "true" ]]; then
    if [[ "${FIRST_RUN}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Routing to updater (first run, download required)"
        supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-updater
    elif [[ "${VEIN_UPDATE_ON_START}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Routing to updater (update check enabled)"
        supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-updater
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Routing to server (auto-update enabled, but update-on-start disabled)"
        supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-server
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Routing to server (auto-update disabled)"
    supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-server
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Bootstrap routing complete"
