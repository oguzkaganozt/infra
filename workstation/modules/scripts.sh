#!/usr/bin/env bash

install_helper_scripts() {
	local source_dir="$1"
	local lib_dir="$2"

	log "Installing helper scripts"
	install -m 0755 "$source_dir/workstation-drive-info.sh" /usr/local/bin/workstation-drive-info
	install -m 0755 "$source_dir/workstation-github-auth.sh" /usr/local/bin/workstation-github-auth
	install -m 0755 "$source_dir/workstation-info.sh" /usr/local/bin/workstation-info
	install -m 0755 "$source_dir/workstation-mount-drive.sh" /usr/local/bin/workstation-mount-drive
	install -m 0755 "$source_dir/workstation-sync-info.sh" /usr/local/bin/workstation-sync-info

	install -d -m 0755 /usr/local/lib/workstation
	install -m 0644 "$lib_dir/config.sh" /usr/local/lib/workstation/config.sh
	install -m 0644 "$lib_dir/env.sh" /usr/local/lib/workstation/env.sh

	rm -f /usr/local/bin/restore-workspace /usr/local/bin/backup-workspace
	rm -f /usr/local/bin/workstation-restore-workspace /usr/local/bin/workstation-backup-workspace
}
