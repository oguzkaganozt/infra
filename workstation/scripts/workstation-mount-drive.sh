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

if [[ -z "${RCLONE_REMOTE:-}" ]]; then
	printf 'RCLONE_REMOTE is required.\n' >&2
	exit 1
fi

DRIVE_DIR="${DRIVE_DIR:-/drive}"
RCLONE_CONFIG="${RCLONE_CONFIG:-/etc/workstation-rclone/rclone.conf}"
RCLONE_REMOTE_PATH="${RCLONE_REMOTE_PATH:-}"
RCLONE_VFS_CACHE_DIR="${RCLONE_VFS_CACHE_DIR:-/var/cache/workstation-rclone}"
RCLONE_VFS_CACHE_MAX_SIZE="${RCLONE_VFS_CACHE_MAX_SIZE:-50G}"
RCLONE_VFS_CACHE_MAX_AGE="${RCLONE_VFS_CACHE_MAX_AGE:-24h}"
RCLONE_DIR_CACHE_TIME="${RCLONE_DIR_CACHE_TIME:-1h}"
RCLONE_POLL_INTERVAL="${RCLONE_POLL_INTERVAL:-1m}"
RCLONE_MOUNT_UID="${RCLONE_MOUNT_UID:-$(id -u "${WORKSTATION_USER:-workstation}")}"
RCLONE_MOUNT_GID="${RCLONE_MOUNT_GID:-$(id -g "${WORKSTATION_USER:-workstation}")}"

mkdir -p "$DRIVE_DIR" "$RCLONE_VFS_CACHE_DIR"

remote_spec="$RCLONE_REMOTE:"
if [[ -n "$RCLONE_REMOTE_PATH" ]]; then
	remote_spec="$remote_spec$RCLONE_REMOTE_PATH"
fi

exec rclone mount "$remote_spec" "$DRIVE_DIR" \
	--config "$RCLONE_CONFIG" \
	--vfs-cache-mode full \
	--vfs-cache-max-size "$RCLONE_VFS_CACHE_MAX_SIZE" \
	--vfs-cache-max-age "$RCLONE_VFS_CACHE_MAX_AGE" \
	--cache-dir "$RCLONE_VFS_CACHE_DIR" \
	--dir-cache-time "$RCLONE_DIR_CACHE_TIME" \
	--poll-interval "$RCLONE_POLL_INTERVAL" \
	--uid "$RCLONE_MOUNT_UID" \
	--gid "$RCLONE_MOUNT_GID" \
	--umask 002 \
	--allow-other
