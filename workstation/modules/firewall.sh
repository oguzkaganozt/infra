#!/usr/bin/env bash

configure_firewall() {
  if [[ "${INSTALL_UFW:-1}" != "1" ]]; then
    log "Skipping UFW configuration"
    return
  fi

  log "Configuring UFW"
  ufw allow OpenSSH >/dev/null || ufw allow 22/tcp >/dev/null
  ufw allow in on tailscale0 >/dev/null || true
  ufw --force enable >/dev/null
}
