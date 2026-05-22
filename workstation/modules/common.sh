#!/usr/bin/env bash

log() {
	printf '[workstation] %s\n' "$*"
}

die() {
	printf '[workstation] ERROR: %s\n' "$*" >&2
	exit 1
}

require_root() {
	if [[ "${EUID}" -ne 0 ]]; then
		die "This script must run as root. Use sudo -E to preserve bootstrap env vars."
	fi
}

apt_get() {
	apt-get -o DPkg::Lock::Timeout=600 "$@"
}

apt_update_once() {
	if [[ "${WORKSTATION_APT_UPDATED:-0}" == "1" ]]; then
		return
	fi

	apt_get update
	WORKSTATION_APT_UPDATED=1
}

ensure_apt_packages() {
	apt_update_once
	apt_get install -y "$@"
}
