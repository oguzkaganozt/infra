#!/usr/bin/env bash

configure_workstation_user() {
	local user_name="${WORKSTATION_USER:-workstation}"

	if ! id "$user_name" >/dev/null 2>&1; then
		log "Creating workstation user: $user_name"
		useradd --create-home --shell /bin/bash --groups sudo "$user_name"
	fi

	if [[ -z "${WORKSTATION_PASSWORD:-}" ]]; then
		log "WORKSTATION_PASSWORD is missing; leaving password login unchanged for $user_name"
		return
	fi

	log "Configuring workstation login password for $user_name"
	printf '%s:%s\n' "$user_name" "$WORKSTATION_PASSWORD" | chpasswd
}
