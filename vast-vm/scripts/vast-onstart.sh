#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
WORKSPACE_OWNER="${WORKSPACE_OWNER:-root:root}"
RESTIC_TAG="${RESTIC_TAG:-workspace}"
INSTALL_SYSTEMD_TIMER="${INSTALL_SYSTEMD_TIMER:-1}"
INSTALL_NOMACHINE="${INSTALL_NOMACHINE:-1}"
NOMACHINE_DEB_URL="${NOMACHINE_DEB_URL:-https://www.nomachine.com/free/linux/64/deb}"
NOMACHINE_USER="${NOMACHINE_USER:-user}"
NOMACHINE_PASSWORD="${NOMACHINE_PASSWORD:-}"
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
  wait_for_apt_locks
  apt-get update
  apt-get install -y ca-certificates curl git restic systemd
}

install_nomachine() {
  if [[ "$INSTALL_NOMACHINE" != "1" ]]; then
    log "Skipping NoMachine install"
    return
  fi

  if command -v /usr/NX/bin/nxserver >/dev/null 2>&1; then
    log "NoMachine is already installed"
    return
  fi

  log "Installing NoMachine"
  local deb_path=/tmp/nomachine.deb
  curl -fsSL "$NOMACHINE_DEB_URL" -o "$deb_path"
  dpkg-deb --info "$deb_path" >/dev/null
  apt-get install -y "$deb_path"
  rm -f "$deb_path"

  if systemctl list-unit-files nxserver.service >/dev/null 2>&1; then
    systemctl enable --now nxserver.service
  fi
}

configure_nomachine_user() {
  if [[ "$INSTALL_NOMACHINE" != "1" || -z "$NOMACHINE_PASSWORD" ]]; then
    return
  fi

  log "Configuring NoMachine login user: $NOMACHINE_USER"
  if ! id "$NOMACHINE_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$NOMACHINE_USER"
  fi

  printf '%s:%s\n' "$NOMACHINE_USER" "$NOMACHINE_PASSWORD" | chpasswd
}

wait_for_apt_locks() {
  local lock
  local waited=0
  local timeout=600
  local locks=(
    /var/lib/dpkg/lock
    /var/lib/dpkg/lock-frontend
    /var/lib/apt/lists/lock
    /var/cache/apt/archives/lock
  )

  while true; do
    lock=""
    for lock in "${locks[@]}"; do
      if fuser "$lock" >/dev/null 2>&1; then
        break
      fi
      lock=""
    done

    if [[ -z "$lock" ]]; then
      return
    fi

    if (( waited >= timeout )); then
      log "Timed out waiting for apt/dpkg locks"
      return 1
    fi

    log "Waiting for apt/dpkg lock: $lock"
    sleep 10
    waited=$((waited + 10))
  done
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
  install_nomachine
  configure_nomachine_user
  write_restic_env
  install_infra_scripts
  restore_workspace
  clone_project
  install_backup_timer
  log "Bootstrap complete"
}

main "$@"
