#!/usr/bin/env bash

install_rclone() {
	if command -v rclone >/dev/null 2>&1; then
		log "rclone is already installed"
	else
		log "Installing rclone"
		ensure_apt_packages rclone
	fi

	if ! command -v fusermount3 >/dev/null 2>&1; then
		log "Installing FUSE support"
		ensure_apt_packages fuse3
	fi
}

configure_rclone_config() {
	local config_dir=/etc/workstation-rclone
	local config_file="${RCLONE_CONFIG:-$(workstation_config_default RCLONE_CONFIG "$config_dir/rclone.conf")}"

	if [[ -n "${RCLONE_CONFIG_B64:-}" ]]; then
		log "Writing rclone config from RCLONE_CONFIG_B64"
		install -d -m 0700 "$(dirname "$config_file")"
		printf '%s' "$RCLONE_CONFIG_B64" | base64 -d >"$config_file"
		chmod 0600 "$config_file"
		remove_rclone_config_b64_from_env
	elif [[ ! -f "$config_file" ]]; then
		die "RCLONE_CONFIG_B64 is required, or provide an existing $config_file"
	fi

	RCLONE_CONFIG="$config_file"
	export RCLONE_CONFIG
}

remove_rclone_config_b64_from_env() {
	local env_file="${WORKSTATION_ENV_FILE:-}"
	[[ -n "$env_file" && -f "$env_file" ]] || return 0

	local tmp_file old_umask line
	old_umask="$(umask)"
	umask 077
	tmp_file="$(mktemp)"
	umask "$old_umask"

	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?RCLONE_CONFIG_B64= ]]; then
			continue
		fi
		printf '%s\n' "$line"
	done <"$env_file" >"$tmp_file"

	install -m 0600 "$tmp_file" "$env_file"
	rm -f "$tmp_file"
	unset RCLONE_CONFIG_B64
}

configure_drive_mount() {
	local systemd_dir="$1"
	local mount_dir="${DRIVE_DIR:-$(workstation_config_default DRIVE_DIR)}"
	local user_name="${WORKSTATION_USER:-$(workstation_config_default WORKSTATION_USER)}"
	local user_id group_id

	if [[ -z "${RCLONE_REMOTE:-}" ]]; then
		die "RCLONE_REMOTE is required for /drive mount"
	fi

	mkdir -p "$mount_dir"
	user_id="$(id -u "$user_name")"
	group_id="$(id -g "$user_name")"
	chown "$user_id:$group_id" "$mount_dir"
	chmod 0755 "$mount_dir"

	install -d -m 0755 /etc/systemd/system/drive-mount.service.d
	{
		printf '[Service]\n'
		printf 'Environment=RCLONE_MOUNT_UID=%s\n' "$user_id"
		printf 'Environment=RCLONE_MOUNT_GID=%s\n' "$group_id"
	} >/etc/systemd/system/drive-mount.service.d/override.conf

	if [[ -f /etc/fuse.conf ]] && ! grep -q '^user_allow_other$' /etc/fuse.conf; then
		printf '\nuser_allow_other\n' >>/etc/fuse.conf
	fi

	install -m 0644 "$systemd_dir/drive-mount.service" /etc/systemd/system/drive-mount.service

	systemctl daemon-reload
	systemctl enable --now drive-mount.service
}

configure_rclone_drive() {
	local systemd_dir="$1"

	install_rclone
	configure_rclone_config
	configure_drive_mount "$systemd_dir"
}
