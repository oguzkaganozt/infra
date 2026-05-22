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

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  printf 'Workspace directory does not exist: %s\n' "$WORKSPACE_DIR" >&2
  exit 1
fi

if ! restic snapshots --tag "$RESTIC_TAG" >/dev/null 2>&1; then
  restic init
fi

restic backup "$WORKSPACE_DIR" \
  --tag "$RESTIC_TAG" \
  --exclude-caches \
  --one-file-system

restic forget \
  --tag "$RESTIC_TAG" \
  --keep-hourly 24 \
  --keep-daily 14 \
  --keep-weekly 8 \
  --prune
