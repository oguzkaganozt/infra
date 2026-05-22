#!/usr/bin/env bash

install_base_packages() {
  log "Installing base packages"
  apt_get update
  apt_get install -y ca-certificates curl git openssh-server restic systemd
}
