#!/usr/bin/env bash

configure_firewall() {
  if [[ "${INSTALL_UFW:-0}" != "1" ]]; then
    log "Skipping UFW configuration"
    return
  fi

  log "Configuring UFW"
  if ! command -v ufw >/dev/null 2>&1; then
    apt_get update
    apt_get install -y ufw
  fi

  ufw allow OpenSSH >/dev/null || ufw allow 22/tcp >/dev/null
  ufw allow in on tailscale0 >/dev/null || true
  ufw --force enable >/dev/null
}
