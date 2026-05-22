#!/usr/bin/env bash

install_desktop() {
	if [[ "${INSTALL_DESKTOP:-1}" != "1" ]]; then
		log "Skipping desktop environment install"
		return
	fi

	if command -v startxfce4 >/dev/null 2>&1; then
		log "Desktop environment is already installed"
		return
	fi

	log "Installing lightweight desktop environment"
	local packages
	local package_args=()
	packages="${DESKTOP_PACKAGES:-xfce4 xfce4-goodies dbus-x11 x11-xserver-utils}"
	read -r -a package_args <<<"$packages"
	ensure_apt_packages "${package_args[@]}"
}
