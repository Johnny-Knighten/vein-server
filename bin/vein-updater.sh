#!/usr/bin/env bash
set -euo pipefail

# Vein Updater - Downloads/updates server via SteamCMD

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Vein server update..."

# Run SteamCMD to download/update Vein server (App ID: 2131400)
steamcmd +force_install_dir /vein-server/server \
         +login anonymous \
         +app_update 2131400 validate \
         +quit

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Update complete"
