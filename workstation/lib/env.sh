#!/usr/bin/env bash

WORKSTATION_ENV_FILE="${WORKSTATION_ENV_FILE:-/etc/workstation.env}"

workstation_env_key_allowed() {
	case "$1" in
	DRIVE_DIR | \
		DESKTOP_PACKAGES | GITHUB_TOKEN | INSTALL_DESKTOP | INSTALL_NOMACHINE | \
		RCLONE_CONFIG | RCLONE_CONFIG_B64 | RCLONE_DIR_CACHE_TIME | \
		RCLONE_POLL_INTERVAL | RCLONE_REMOTE | RCLONE_REMOTE_PATH | \
		RCLONE_VFS_CACHE_DIR | RCLONE_VFS_CACHE_MAX_AGE | RCLONE_VFS_CACHE_MAX_SIZE | \
		INFISICAL_API_URL | INFISICAL_ENV | INFISICAL_PROJECT_ID | INFISICAL_SECRET_PATH | \
		NOMACHINE_DEB_URL | NOMACHINE_INSTALL_TIMEOUT | \
		PUBLIC_IPADDR | \
		SYNCTHING_DEVICE_NAME | SYNCTHING_FOLDER_ID | SYNCTHING_FOLDER_LABEL | \
		SYNCTHING_GUI_ADDRESS | SYNCTHING_HOME | SYNCTHING_PEER_ADDRESS | \
		SYNCTHING_PEER_DEVICE_ID | SYNCTHING_PEER_DEVICE_IDS | SYNCTHING_PEER_NAME | SYNCTHING_RESCAN_INTERVAL | \
		WORKSPACE_CHOWN_RECURSIVE | \
		TS_AUTHKEY | TS_ENABLE_SSH | TS_EXTRA_ARGS | TS_HOSTNAME | \
		VAST_TCP_PORT_22 | VAST_TCP_PORT_4000 | \
		WORKSPACE_DIR | WORKSTATION_PASSWORD | WORKSTATION_ROLE | WORKSTATION_USER)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

strip_env_quotes() {
	local value="$1"
	if [[ ${#value} -ge 2 && "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
		value="${value:1:${#value}-2}"
	elif [[ ${#value} -ge 2 && "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
		value="${value:1:${#value}-2}"
	fi
	printf '%s' "$value"
}

load_workstation_env() {
	local env_file="${1:-$WORKSTATION_ENV_FILE}"
	[[ -r "$env_file" ]] || return 0

	local line key value
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		[[ "$line" == *=* ]] || continue

		key="${line%%=*}"
		value="${line#*=}"
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		workstation_env_key_allowed "$key" || continue

		value="$(strip_env_quotes "$value")"
		printf -v "$key" '%s' "$value"
		declare -gx "$key"
	done <"$env_file"
}

set_workstation_defaults() {
	WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
	DRIVE_DIR="${DRIVE_DIR:-/drive}"
	WORKSTATION_USER="${WORKSTATION_USER:-workstation}"
	WORKSTATION_ROLE="${WORKSTATION_ROLE:-workstation}"
	if [[ "$WORKSTATION_ROLE" == "sync-node" ]]; then
		INSTALL_DESKTOP="${INSTALL_DESKTOP:-0}"
		INSTALL_NOMACHINE="${INSTALL_NOMACHINE:-0}"
	else
		INSTALL_DESKTOP="${INSTALL_DESKTOP:-1}"
		INSTALL_NOMACHINE="${INSTALL_NOMACHINE:-1}"
	fi
	SYNCTHING_FOLDER_ID="${SYNCTHING_FOLDER_ID:-workspace}"
	SYNCTHING_FOLDER_LABEL="${SYNCTHING_FOLDER_LABEL:-workspace}"
	RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive}"
	export DRIVE_DIR INSTALL_DESKTOP INSTALL_NOMACHINE RCLONE_REMOTE SYNCTHING_FOLDER_ID SYNCTHING_FOLDER_LABEL WORKSPACE_DIR WORKSTATION_ROLE WORKSTATION_USER
}
