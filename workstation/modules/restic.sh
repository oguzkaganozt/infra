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

set_restic_defaults() {
  RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:https://c7a7c7c9096e7a8fc974cec9ded52671.r2.cloudflarestorage.com/vast-workspace/main}"
  AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  export RESTIC_REPOSITORY AWS_DEFAULT_REGION
}

install_helper_scripts() {
  local source_dir="$1"

  log "Installing helper scripts"
  install -m 0755 "$source_dir/restore-workspace.sh" /usr/local/bin/restore-workspace
  install -m 0755 "$source_dir/backup-workspace.sh" /usr/local/bin/backup-workspace
  install -m 0755 "$source_dir/workstation-info.sh" /usr/local/bin/workstation-info
}

restore_workspace() {
  set_restic_defaults
  local workspace_dir="${WORKSPACE_DIR:-/workspace}"
  mkdir -p "$workspace_dir"
  chown "$(workspace_owner)" "$workspace_dir"

  if [[ -z "${RESTIC_PASSWORD:-}" || -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    log "Restic/R2 secrets are missing; skipping restore"
    return
  fi

  log "Restoring latest workspace snapshot"
  if ! /usr/local/bin/restore-workspace; then
    log "Restore failed or no snapshot exists; continuing with empty workspace"
  fi

  chown -R "$(workspace_owner)" "$workspace_dir"
}
