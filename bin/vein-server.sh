#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Vein Server - Starting"

trap cleanup SIGTERM SIGINT

cleanup() {
    echo "Vein Server - Shutdown signal received, stopping server"
    # Kill the actual VeinServer binary (child of VeinServer.sh)
    pkill -TERM -f "VeinServer-Linux-Test" 2>/dev/null || true
    if [ -n "$SERVER_PID" ]; then
        wait "$SERVER_PID" 2>/dev/null || true
    fi
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

    # Run server as child process so we can catch signals and forward them
    ./VeinServer.sh -log &
    SERVER_PID=$!

    echo "Vein Server - Server started with PID $SERVER_PID"

    # Wait for server to exit
    wait "$SERVER_PID"
}

start_server
