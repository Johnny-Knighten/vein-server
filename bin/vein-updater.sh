#!/usr/bin/env bash

set -e

[[ -z "${DEBUG}" ]] || [[ "${DEBUG,,}" = "false" ]] || [[ "${DEBUG,,}" = "0" ]] || set -x

echo "Updater - Starting"

main() {
    download_and_update_vein_server
    launch_vein_server
}

launch_vein_server() {
    echo "Updater - Launching Vein Server"
    supervisorctl start vein-server
}

download_and_update_vein_server() {
    local app_id="2131400"
    local steamcmd_args=("+force_install_dir" "$SERVER_DIR" "+login" "anonymous")

    if [[ "$EXPERIMENTAL_BUILD" = "True" ]]; then
        echo "Updater - Using Experimental Build"
        app_id="2600250"
        steamcmd_args+=("+app_update" "$app_id" "-beta" "experimental")
    else
        steamcmd_args+=("+app_update" "$app_id")
    fi

    if [[ "$VALIDATE_SERVER_FILES" != "False" ]]; then
        steamcmd_args+=("validate")
    else
        echo "Updater - Skipping SteamCMD Validation of Server Files"
    fi

    steamcmd_args+=("+quit")

    steamcmd "${steamcmd_args[@]}"
}

main
