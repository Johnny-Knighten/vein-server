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
    if [[ "$DRY_RUN" = "True" ]]; then
        echo "DRY_RUN - supervisorctl start vein-server"
    else
        supervisorctl start vein-server
    fi
}

download_and_update_vein_server() {
    local app_id="2131400"
    local beta_flag=""
    local validate_flag="validate"

    if [ "$EXPERIMENTAL_BUILD" = "True" ]; then
        echo "Updater - Using Experimental Build"
        app_id="2600250"
        beta_flag="-beta experimental"
    fi

    if [ "$SKIP_FILE_VALIDATION" = "True" ]; then
        echo "Updater - Skipping SteamCMD Validation of Server Files"
        validate_flag=""
    fi

    local app_update="+app_update $app_id $beta_flag $validate_flag"

    local install_dir="+force_install_dir $SERVER_DIR"

    if [[ "$DRY_RUN" = "True" ]]; then
        echo "DRY_RUN - steamcmd \"$install_dir\" +login anonymous \"$app_update\" +quit"
    else
        steamcmd "$install_dir" +login anonymous "$app_update" +quit
    fi
}

main
