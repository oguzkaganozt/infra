#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$script_dir/../lib/env.sh" ]]; then
	# shellcheck disable=SC1091
	source "$script_dir/../lib/env.sh"
else
	# shellcheck disable=SC1091
	source "${WORKSTATION_LIB_DIR:-/usr/local/lib/workstation}/env.sh"
fi

load_workstation_env
set_workstation_defaults

if [[ "${EUID}" -ne 0 ]]; then
	printf 'Run as root: sudo workstation-github-auth\n' >&2
	exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
	printf 'GITHUB_TOKEN is missing from %s.\n' "$WORKSTATION_ENV_FILE" >&2
	exit 1
fi

if ! id "$WORKSTATION_USER" >/dev/null 2>&1; then
	printf 'Workstation user does not exist: %s\n' "$WORKSTATION_USER" >&2
	exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
	apt-get -o DPkg::Lock::Timeout=600 update
	apt-get -o DPkg::Lock::Timeout=600 install -y gh
fi

sudo -H -u "$WORKSTATION_USER" env WORKSTATION_GITHUB_TOKEN="$GITHUB_TOKEN" bash -c '
  set -euo pipefail
  unset GITHUB_TOKEN GH_TOKEN
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    printf "%s\n" "$WORKSTATION_GITHUB_TOKEN" | gh auth login --hostname github.com --with-token
  fi
  gh auth setup-git --hostname github.com
  unset WORKSTATION_GITHUB_TOKEN
  chmod 700 "$HOME/.config/gh" 2>/dev/null || true
  chmod 600 "$HOME/.config/gh/hosts.yml" 2>/dev/null || true
  gh auth status --hostname github.com
'
