#!/usr/bin/env bash

install_infisical_cli() {
  if command -v infisical >/dev/null 2>&1; then
    log "Infisical CLI is already installed"
    return
  fi

  log "Installing Infisical CLI"
  curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash
  apt_get update
  apt_get install -y infisical
}

fetch_infisical_env() {
  INFISICAL_API_URL="${INFISICAL_API_URL:-https://app.infisical.com}"
  INFISICAL_ENV="${INFISICAL_ENV:-prod}"
  INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/}"
  export INFISICAL_API_URL INFISICAL_DISABLE_UPDATE_CHECK=true

  if [[ -z "${INFISICAL_CLIENT_ID:-}" || -z "${INFISICAL_CLIENT_SECRET:-}" || -z "${INFISICAL_PROJECT_ID:-}" ]]; then
    if [[ -f "$WORKSTATION_ENV_FILE" ]]; then
      log "Infisical bootstrap credentials are missing; using existing $WORKSTATION_ENV_FILE"
      return
    fi

    die "INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, and INFISICAL_PROJECT_ID are required"
  fi

  log "Fetching workstation secrets from Infisical"
  local token
  token="$(infisical login \
    --method=universal-auth \
    --client-id="$INFISICAL_CLIENT_ID" \
    --client-secret="$INFISICAL_CLIENT_SECRET" \
    --silent \
    --plain)"

  umask 077
  INFISICAL_TOKEN="$token" infisical export \
    --format=dotenv \
    --env="$INFISICAL_ENV" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --path="$INFISICAL_SECRET_PATH" \
    --output-file="$WORKSTATION_ENV_FILE"

  {
    printf '\n'
    printf 'INFISICAL_API_URL=%q\n' "$INFISICAL_API_URL"
    printf 'INFISICAL_ENV=%q\n' "$INFISICAL_ENV"
    printf 'INFISICAL_SECRET_PATH=%q\n' "$INFISICAL_SECRET_PATH"
  } >> "$WORKSTATION_ENV_FILE"

  chmod 0600 "$WORKSTATION_ENV_FILE"
}
