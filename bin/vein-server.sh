#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Vein Server - Starting"

trap cleanup SIGTERM SIGINT

main() {
    handle_old_server_log
    start_server
}

cleanup() {
    echo "Vein Server - Shutdown signal received, stopping server"
    pkill -TERM VeinServer || true
    exit 0
}

handle_old_server_log() {
    # shellcheck disable=SC2153
    local log_file="${SERVER_DIR}/Vein/Saved/Logs/Vein.log"
    if [ -f "$log_file" ]; then
        echo "Vein Server - Removing old log file"
        rm -f "$log_file"
    fi
}

start_server() {
    cd "$SERVER_DIR" || exit 1

    if [ ! -f "./VeinServer.sh" ]; then
        echo "Vein Server - ERROR: VeinServer.sh not found"
        exit 1
    fi

    echo "Vein Server - Ensure steamclient.so is linked"
    ln -s /home/steam/.local/share/Steam/steamcmd/linux64/steamclient.so "${SERVER_DIR}/Vein/Binaries/Linux/steamclient.so"

    echo "Vein Server - Launching server process"

    if [[ "$DRY_RUN" = "True" ]]; then
        echo "DRY_RUN - ./VeinServer.sh -log"
    else
        ./VeinServer.sh -log &
        SERVER_PID=$!

        # Wait for log file to appear (300 second timeout)
        local log_file="${SERVER_DIR}/Vein/Saved/Logs/Vein.log"
        local timeout=300
        local elapsed=0

        echo "Vein Server - Waiting for log file to appear..."
        while [ ! -f "$log_file" ] && [ $elapsed -lt $timeout ]; do
            sleep 1
            ((elapsed++))
        done

        if [ -f "$log_file" ]; then
            echo "Vein Server - Log file found, tailing output"
            tail -f "$log_file"
        else
            echo "Vein Server - WARNING: Log file not found after ${timeout}s"
            wait $SERVER_PID
        fi
    fi
}

main
