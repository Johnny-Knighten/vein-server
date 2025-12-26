#!/usr/bin/env bash
set -euo pipefail

# Vein Updater - Downloads/updates server via SteamCMD

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Vein server update..."

# Run SteamCMD to download/update Vein server (App ID: 2131400)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Running SteamCMD..."
if ! steamcmd +force_install_dir /vein-server/server \
              +login anonymous \
              +app_update 2131400 validate \
              +quit; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] SteamCMD update failed"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SteamCMD update complete"

# File validation (if enabled)
VEIN_VALIDATE_FILES="${VEIN_VALIDATE_FILES:-true}"
if [[ "${VEIN_VALIDATE_FILES}" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Validating server files..."

    # Check if VeinServer.sh exists and is executable
    if [[ ! -f "/vein-server/server/VeinServer.sh" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] VeinServer.sh not found after update"
        exit 1
    fi

    if [[ ! -x "/vein-server/server/VeinServer.sh" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] VeinServer.sh not executable, setting permissions..."
        chmod +x /vein-server/server/VeinServer.sh
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] File validation passed"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] File validation disabled (VEIN_VALIDATE_FILES=false)"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Update complete, starting server..."

# Start vein-server process via supervisorctl
supervisorctl -c /vein-server/supervisord/supervisord.conf start vein-server
