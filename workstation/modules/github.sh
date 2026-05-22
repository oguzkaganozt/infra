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
  sudo -H -u "$user_name" env GITHUB_TOKEN="$GITHUB_TOKEN" bash -c '
    set -euo pipefail
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
      printf "%s\n" "$GITHUB_TOKEN" | gh auth login --hostname github.com --with-token
    fi
    gh auth setup-git --hostname github.com
    chmod 700 "$HOME/.config/gh" 2>/dev/null || true
    chmod 600 "$HOME/.config/gh/hosts.yml" 2>/dev/null || true
  '
}
