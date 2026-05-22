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

drive_dir="${DRIVE_DIR:-/drive}"

printf 'Google Drive mount\n'
printf '  Service: %s\n' "$(systemctl is-active drive-mount.service 2>/dev/null || true)"
printf '  Mount path: %s\n' "$drive_dir"
printf '  Remote: %s:%s\n' "${RCLONE_REMOTE:-unknown}" "${RCLONE_REMOTE_PATH:-}"
if mountpoint -q "$drive_dir"; then
	printf '  Mounted: yes\n'
else
	printf '  Mounted: no\n'
fi
