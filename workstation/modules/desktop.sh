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
  packages="${DESKTOP_PACKAGES:-xfce4 xfce4-goodies dbus-x11 x11-xserver-utils}"
  # shellcheck disable=SC2086
  apt_get install -y $packages
}
