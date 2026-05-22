#!/usr/bin/env bash

install_nomachine() {
  if [[ "${INSTALL_NOMACHINE:-1}" != "1" ]]; then
    log "Skipping NoMachine install"
    return
  fi

  if command -v /usr/NX/bin/nxserver >/dev/null 2>&1; then
    log "NoMachine is already installed"
    return
  fi

  log "Installing NoMachine"
  local deb_path=/tmp/nomachine.deb
  local deb_url="${NOMACHINE_DEB_URL:-https://www.nomachine.com/free/linux/64/deb}"

  curl -fsSL "$deb_url" -o "$deb_path"
  dpkg-deb --info "$deb_path" >/dev/null
  apt_get install -y "$deb_path"
  rm -f "$deb_path"

  systemctl enable --now nxserver.service || true
}

configure_nomachine_user() {
  if [[ "${INSTALL_NOMACHINE:-1}" != "1" ]]; then
    return
  fi

  local user_name="${NOMACHINE_USER:-workstation}"

  if ! id "$user_name" >/dev/null 2>&1; then
    log "Creating workstation user: $user_name"
    useradd --create-home --shell /bin/bash --groups sudo "$user_name"
  fi

  if [[ -n "${NOMACHINE_PASSWORD:-}" ]]; then
    log "Configuring NoMachine login user: $user_name"
    printf '%s:%s\n' "$user_name" "$NOMACHINE_PASSWORD" | chpasswd
  else
    log "NOMACHINE_PASSWORD is missing; NoMachine login password was not changed"
  fi
}
