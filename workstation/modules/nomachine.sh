#!/usr/bin/env bash

install_nomachine() {
	if [[ "${INSTALL_NOMACHINE:-$(workstation_config_default INSTALL_NOMACHINE)}" != "1" ]]; then
		log "Skipping NoMachine install"
		return
	fi

	if command -v /usr/NX/bin/nxserver >/dev/null 2>&1; then
		log "NoMachine is already installed"
		return
	fi

	log "Installing NoMachine"
	local deb_path=/tmp/nomachine.deb
	local deb_url="${NOMACHINE_DEB_URL:-$(workstation_config_default NOMACHINE_DEB_URL)}"
	local watchdog_pid

	curl -fsSL "$deb_url" -o "$deb_path"
	dpkg-deb --info "$deb_path" >/dev/null

	# NoMachine 9.x can occasionally hang in nxserver.bin --subscription during
	# package post-install on fresh cloud images, even after the service is ready.
	(
		while true; do
			sleep 30
			pkill -9 -f '[n]xserver\.bin --subscription' 2>/dev/null || true
		done
	) &
	watchdog_pid="$!"

	if ! timeout "${NOMACHINE_INSTALL_TIMEOUT:-$(workstation_config_default NOMACHINE_INSTALL_TIMEOUT)}" apt-get -o DPkg::Lock::Timeout=600 install -y "$deb_path"; then
		kill "$watchdog_pid" 2>/dev/null || true
		wait "$watchdog_pid" 2>/dev/null || true
		rm -f "$deb_path"
		die "NoMachine install failed or timed out"
	fi

	kill "$watchdog_pid" 2>/dev/null || true
	wait "$watchdog_pid" 2>/dev/null || true
	rm -f "$deb_path"

	systemctl enable --now nxserver.service || true
}
