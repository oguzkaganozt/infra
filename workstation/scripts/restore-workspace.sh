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
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:https://c7a7c7c9096e7a8fc974cec9ded52671.r2.cloudflarestorage.com/vast-workspace/main}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
export RESTIC_REPOSITORY AWS_DEFAULT_REGION

if [[ -z "${RESTIC_PASSWORD:-}" || -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  printf 'RESTIC_PASSWORD, AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY are required.\n' >&2
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
