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
        echo "Vein Bootstrap - Generating configs"

        # Transform simple ENV vars to CONFIG_ vars for Game.ini
        # Pattern: export CONFIG_<filename>_<section_with_SLASH_DOT>_<variable>="${SIMPLE_VAR}"
        # Python script converts SLASH → / and DOT → . in section names

        # [/Script/Engine.GameSession]
        export CONFIG_Game_SLASH_Script_SLASH_Engine_DOT_GameSession_MaxPlayers="${VEIN_SERVER_MAX_PLAYERS:-16}"

        # [/Script/Vein.VeinGameSession]
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_ServerName="${VEIN_SERVER_NAME:-Vein Server}"
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_ServerDescription="${VEIN_SERVER_DESCRIPTION:-A Vein dedicated server}"
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_Password="${VEIN_SERVER_PASSWORD:-}"
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_bPublic="${VEIN_SERVER_PUBLIC:-True}"
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_BindAddr="${VEIN_BIND_ADDR:-0.0.0.0}"
        export CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_HeartbeatInterval="${VEIN_HEARTBEAT_INTERVAL:-5.0}"

        # [URL]
        export CONFIG_Game_URL_Port="${VEIN_SERVER_PORT:-7777}"

        # [OnlineSubsystemSteam]
        export CONFIG_Game_OnlineSubsystemSteam_GameServerQueryPort="${VEIN_SERVER_QUERY_PORT:-27015}"
        export CONFIG_Game_OnlineSubsystemSteam_bVACEnabled="${VEIN_VAC_ENABLED:-0}"

        # Call Python script to generate INI files from CONFIG_ vars
        python3 /usr/local/bin/config_from_env_vars/main.py --path "${SERVER_DIR}/Vein/Saved/Config/LinuxServer"
    else
        echo "Vein Bootstrap - Skipping (MANUAL_CONFIG=True)"
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
