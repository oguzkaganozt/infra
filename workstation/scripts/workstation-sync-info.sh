#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$script_dir/../lib/env.sh" ]]; then
	# shellcheck disable=SC1091
	source "$script_dir/../lib/env.sh"
else
	# shellcheck disable=SC1091
	source "${WORKSTATION_LIB_DIR:-/usr/local/lib/workstation}/env.sh"
fi

load_workstation_env
set_workstation_defaults

user_name="${WORKSTATION_USER:-workstation}"
user_home="$(getent passwd "$user_name" | cut -d: -f6)"
syncthing_home="${SYNCTHING_HOME:-$user_home/.local/state/syncthing}"

printf 'Syncthing\n'
printf '  Service: %s\n' "$(systemctl is-active workstation-syncthing.service 2>/dev/null || true)"
printf '  Role: %s\n' "${WORKSTATION_ROLE:-workstation}"
printf '  Folder: %s\n' "${SYNCTHING_FOLDER_ID:-workspace}"
printf '  Path: %s\n' "${WORKSPACE_DIR:-/workspace}"
if command -v syncthing >/dev/null 2>&1 && [[ -d "$syncthing_home" ]]; then
	printf '  Device ID: %s\n' "$(sudo -H -u "$user_name" syncthing --home="$syncthing_home" device-id 2>/dev/null || true)"
else
	printf '  Device ID: unknown\n'
fi
