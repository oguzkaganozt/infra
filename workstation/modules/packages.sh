#!/usr/bin/env bash

install_base_packages() {
	log "Installing base packages"
	ensure_apt_packages ca-certificates curl git openssh-server python3 systemd
}
