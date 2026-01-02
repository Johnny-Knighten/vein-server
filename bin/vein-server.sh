#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Vein Server - Starting"

trap cleanup SIGTERM SIGINT

cleanup() {
    echo "Vein Server - Shutdown signal received, stopping server"
    pkill -TERM VeinServer || true
    exit 0
}

start_server() {
    cd "$SERVER_DIR" || exit 1

    if [ ! -f "./VeinServer.sh" ]; then
        echo "Vein Server - ERROR: VeinServer.sh not found"
        exit 1
    fi

    echo "Vein Server - Ensure steamclient.so is linked"
    ln -sf /home/steam/.local/share/Steam/steamcmd/linux64/steamclient.so "${SERVER_DIR}/Vein/Binaries/Linux/steamclient.so"

    echo "Vein Server - Launching server process"

    # Run server in foreground - output goes directly to stdout/stderr
    exec ./VeinServer.sh -log
}

start_server
