#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
WORKSPACE_OWNER="${WORKSPACE_OWNER:-root:root}"
RESTIC_TAG="${RESTIC_TAG:-workspace}"
INSTALL_SYSTEMD_TIMER="${INSTALL_SYSTEMD_TIMER:-1}"
PROJECT_REPO_URL="${PROJECT_REPO_URL:-}"
PROJECT_DIR="${PROJECT_DIR:-$WORKSPACE_DIR/project}"

log() {
  printf '[vast-onstart] %s\n' "$*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log "This script must run as root."
    exit 1
  fi
}

install_packages() {
  log "Installing base packages"
  apt-get update
  apt-get install -y ca-certificates curl git restic systemd
}

write_restic_env() {
  log "Writing /etc/vast-workspace.env"
  umask 077
  {
    printf 'WORKSPACE_DIR=%q\n' "$WORKSPACE_DIR"
    printf 'RESTIC_TAG=%q\n' "$RESTIC_TAG"
    [[ -n "${RESTIC_REPOSITORY:-}" ]] && printf 'RESTIC_REPOSITORY=%q\n' "$RESTIC_REPOSITORY"
    [[ -n "${RESTIC_PASSWORD:-}" ]] && printf 'RESTIC_PASSWORD=%q\n' "$RESTIC_PASSWORD"
    [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && printf 'AWS_ACCESS_KEY_ID=%q\n' "$AWS_ACCESS_KEY_ID"
    [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] && printf 'AWS_SECRET_ACCESS_KEY=%q\n' "$AWS_SECRET_ACCESS_KEY"
    [[ -n "${AWS_DEFAULT_REGION:-}" ]] && printf 'AWS_DEFAULT_REGION=%q\n' "$AWS_DEFAULT_REGION"
  } > /etc/vast-workspace.env
}

install_infra_scripts() {
  local source_dir
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  log "Installing helper scripts"
  install -m 0755 "$source_dir/restore-workspace.sh" /usr/local/bin/restore-workspace
  install -m 0755 "$source_dir/backup-workspace.sh" /usr/local/bin/backup-workspace
}

install_backup_timer() {
  if [[ "$INSTALL_SYSTEMD_TIMER" != "1" ]]; then
    log "Skipping systemd backup timer"
    return
  fi

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  log "Installing systemd backup timer"
  install -m 0644 "$repo_root/systemd/workspace-backup.service" /etc/systemd/system/workspace-backup.service
  install -m 0644 "$repo_root/systemd/workspace-backup.timer" /etc/systemd/system/workspace-backup.timer
  install -m 0644 "$repo_root/systemd/workspace-backup-shutdown.service" /etc/systemd/system/workspace-backup-shutdown.service
  systemctl daemon-reload
  systemctl enable --now workspace-backup.timer
  systemctl enable --now workspace-backup-shutdown.service
}

restore_workspace() {
  mkdir -p "$WORKSPACE_DIR"
  chown "$WORKSPACE_OWNER" "$WORKSPACE_DIR"

  if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
    log "RESTIC_REPOSITORY or RESTIC_PASSWORD is missing; skipping restore"
    return
  fi

  log "Restoring latest workspace snapshot"
  if ! /usr/local/bin/restore-workspace; then
    log "Restore failed or no snapshot exists; continuing with empty workspace"
  fi
}

clone_project() {
  if [[ -z "$PROJECT_REPO_URL" ]]; then
    return
  fi

  if [[ -d "$PROJECT_DIR/.git" ]]; then
    log "Project repo already exists at $PROJECT_DIR"
    return
  fi

  log "Cloning project repo into $PROJECT_DIR"
  mkdir -p "$(dirname "$PROJECT_DIR")"
  git clone "$PROJECT_REPO_URL" "$PROJECT_DIR"
}

main() {
  require_root
  install_packages
  write_restic_env
  install_infra_scripts
  restore_workspace
  clone_project
  install_backup_timer
  log "Bootstrap complete"
}

main "$@"
