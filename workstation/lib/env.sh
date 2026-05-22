#!/usr/bin/env bash

workstation_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$workstation_lib_dir/config.sh"

WORKSTATION_ENV_FILE="${WORKSTATION_ENV_FILE:-$(workstation_config_default WORKSTATION_ENV_FILE)}"

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
	WORKSPACE_DIR="${WORKSPACE_DIR:-$(workstation_config_default WORKSPACE_DIR)}"
	DRIVE_DIR="${DRIVE_DIR:-$(workstation_config_default DRIVE_DIR)}"
	WORKSTATION_USER="${WORKSTATION_USER:-$(workstation_config_default WORKSTATION_USER)}"
	WORKSTATION_ROLE="${WORKSTATION_ROLE:-$(workstation_config_default WORKSTATION_ROLE)}"
	if [[ "$WORKSTATION_ROLE" == "base" ]]; then
		INSTALL_DESKTOP="${INSTALL_DESKTOP:-0}"
		INSTALL_NOMACHINE="${INSTALL_NOMACHINE:-0}"
	else
		INSTALL_DESKTOP="${INSTALL_DESKTOP:-$(workstation_config_default INSTALL_DESKTOP)}"
		INSTALL_NOMACHINE="${INSTALL_NOMACHINE:-$(workstation_config_default INSTALL_NOMACHINE)}"
	fi
	SYNCTHING_FOLDER_ID="${SYNCTHING_FOLDER_ID:-$(workstation_config_default SYNCTHING_FOLDER_ID)}"
	SYNCTHING_FOLDER_LABEL="${SYNCTHING_FOLDER_LABEL:-$(workstation_config_default SYNCTHING_FOLDER_LABEL)}"
	RCLONE_REMOTE="${RCLONE_REMOTE:-$(workstation_config_default RCLONE_REMOTE)}"
	export DRIVE_DIR INSTALL_DESKTOP INSTALL_NOMACHINE RCLONE_REMOTE SYNCTHING_FOLDER_ID SYNCTHING_FOLDER_LABEL WORKSPACE_DIR WORKSTATION_ROLE WORKSTATION_USER
}
