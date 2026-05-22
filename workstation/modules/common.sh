#!/usr/bin/env bash

WORKSTATION_ENV_FILE="${WORKSTATION_ENV_FILE:-/etc/workstation.env}"

log() {
  printf '[workstation] %s\n' "$*"
}

die() {
  printf '[workstation] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must run as root. Use sudo -E to preserve bootstrap env vars."
  fi
}

apt_get() {
  apt-get -o DPkg::Lock::Timeout=600 "$@"
}

load_workstation_env() {
  if [[ -f "$WORKSTATION_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$WORKSTATION_ENV_FILE"
    set +a
  fi
}

service_is_active() {
  systemctl is-active --quiet "$1" 2>/dev/null
}
