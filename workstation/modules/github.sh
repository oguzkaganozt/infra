#!/usr/bin/env bash

install_github_cli() {
  if command -v gh >/dev/null 2>&1; then
    log "GitHub CLI is already installed"
    return
  fi

  log "Installing GitHub CLI"
  apt_get update
  apt_get install -y gh
}

configure_github_access() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log "GITHUB_TOKEN is missing; skipping GitHub auth"
    return
  fi

  local user_name="${WORKSTATION_USER:-workstation}"
  if ! id "$user_name" >/dev/null 2>&1; then
    die "Workstation user does not exist: $user_name"
  fi

  install_github_cli

  log "Configuring GitHub CLI and git HTTPS access for $user_name"
  /usr/local/bin/workstation-github-auth
}
