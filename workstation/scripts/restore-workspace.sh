#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/workstation.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
RESTIC_TAG="${RESTIC_TAG:-workspace}"

if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
  printf 'RESTIC_REPOSITORY and RESTIC_PASSWORD are required.\n' >&2
  exit 1
fi

if ! restic snapshots --tag "$RESTIC_TAG" >/dev/null 2>&1; then
  restic init
fi

if ! restic snapshots --tag "$RESTIC_TAG" | grep -q "$RESTIC_TAG"; then
  printf 'No snapshots found for tag %s.\n' "$RESTIC_TAG"
  exit 0
fi

mkdir -p "$WORKSPACE_DIR"
restic restore latest --target / --tag "$RESTIC_TAG"
