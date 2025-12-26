#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Vein Bootstrap - Starting"

main() {
    generate_config_files
    check_if_server_files_exist
    auto_update_server
    launch_vein_server
}

launch_vein_server() {
    echo "Vein Bootstrap - Launching Vein Server"
    if [[ "$DRY_RUN" = "True" ]]; then
        echo "DRY_RUN - supervisorctl start vein-server"
    else
        supervisorctl start vein-server
    fi
}

launch_update_service() {
    echo "Vein Bootstrap - Launching Updater Service"
    if [[ "$DRY_RUN" = "True" ]]; then
        echo "DRY_RUN - supervisorctl start vein-updater"
    else
        supervisorctl start vein-updater
    fi
    exit 0
}

generate_config_files() {
    mkdir -p "${SERVER_DIR}/Vein/Saved/Config/LinuxServer"

    if [[ ! -f "${SERVER_DIR}/Vein/Saved/Config/LinuxServer/Game.ini" || "$MANUAL_CONFIG" != "True" ]]; then
        echo "Vein Bootstrap - Generating Game.ini and Engine.ini"

        # TODO: Config generation will be implemented in Phase 3
        # For now, just create empty config files
        touch "${SERVER_DIR}/Vein/Saved/Config/LinuxServer/Game.ini"
        touch "${SERVER_DIR}/Vein/Saved/Config/LinuxServer/Engine.ini"
    else
        echo "Vein Bootstrap - Skipping config generation, MANUAL_CONFIG is True"
    fi
}

check_if_server_files_exist() {
    if [ "$(find "$SERVER_DIR" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ]; then
        echo "Vein Bootstrap - No Server Files Found, Downloading Server"
        launch_update_service
    fi
}

auto_update_server() {
    if [ "$UPDATE_ON_BOOT" = "True" ]; then
        echo "Vein Bootstrap - Update On Boot Enabled"
        launch_update_service
    else
        echo "Vein Bootstrap - Update On Boot Disabled, Skipping"
    fi
}

main
