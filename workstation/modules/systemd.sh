#!/usr/bin/env bash

install_backup_timer() {
  local systemd_dir="$1"

  if [[ "${INSTALL_SYSTEMD_TIMER:-1}" != "1" ]]; then
    log "Skipping systemd backup timer"
    return
  fi

  if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
    log "Skipping systemd backup timer because Restic secrets are missing"
    return
  fi

  log "Installing systemd backup timer"
  install -m 0644 "$systemd_dir/workspace-backup.service" /etc/systemd/system/workspace-backup.service
  install -m 0644 "$systemd_dir/workspace-backup.timer" /etc/systemd/system/workspace-backup.timer
  install -m 0644 "$systemd_dir/workspace-backup-shutdown.service" /etc/systemd/system/workspace-backup-shutdown.service
  systemctl daemon-reload
  systemctl enable --now workspace-backup.timer
  systemctl enable --now workspace-backup-shutdown.service
}
