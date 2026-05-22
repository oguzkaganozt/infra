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

  if ! timeout "${NOMACHINE_INSTALL_TIMEOUT:-1800}" apt-get -o DPkg::Lock::Timeout=600 install -y "$deb_path"; then
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

configure_workstation_user() {
  local user_name="${WORKSTATION_USER:-workstation}"
  local user_password="${WORKSTATION_PASSWORD:-password}"

  if ! id "$user_name" >/dev/null 2>&1; then
    log "Creating workstation user: $user_name"
    useradd --create-home --shell /bin/bash --groups sudo "$user_name"
  fi

  log "Configuring workstation login user: $user_name"
  printf '%s:%s\n' "$user_name" "$user_password" | chpasswd
}
