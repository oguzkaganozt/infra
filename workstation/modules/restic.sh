#!/usr/bin/env bash

workspace_owner() {
  if [[ -n "${WORKSPACE_OWNER:-}" ]]; then
    printf '%s' "$WORKSPACE_OWNER"
    return
  fi

  if [[ -n "${NOMACHINE_USER:-}" ]] && id "$NOMACHINE_USER" >/dev/null 2>&1; then
    printf '%s:%s' "$NOMACHINE_USER" "$NOMACHINE_USER"
    return
  fi

  printf 'root:root'
}

install_helper_scripts() {
  local source_dir="$1"

  log "Installing helper scripts"
  install -m 0755 "$source_dir/restore-workspace.sh" /usr/local/bin/restore-workspace
  install -m 0755 "$source_dir/backup-workspace.sh" /usr/local/bin/backup-workspace
  install -m 0755 "$source_dir/workstation-info.sh" /usr/local/bin/workstation-info
}

restore_workspace() {
  local workspace_dir="${WORKSPACE_DIR:-/workspace}"
  mkdir -p "$workspace_dir"
  chown "$(workspace_owner)" "$workspace_dir"

  if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
    log "RESTIC_REPOSITORY or RESTIC_PASSWORD is missing; skipping restore"
    return
  fi

  log "Restoring latest workspace snapshot"
  if ! /usr/local/bin/restore-workspace; then
    log "Restore failed or no snapshot exists; continuing with empty workspace"
  fi

  chown -R "$(workspace_owner)" "$workspace_dir"
}
