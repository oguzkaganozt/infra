#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

WORKSTATION_REPO_URL="${WORKSTATION_REPO_URL:-https://github.com/oguzkaganozt/infra.git}"
WORKSTATION_REPO_BRANCH="${WORKSTATION_REPO_BRANCH:-main}"
WORKSTATION_REPO_DIR="${WORKSTATION_REPO_DIR:-/opt/workstation-infra}"

script_path="${BASH_SOURCE[0]:-$0}"
if script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd)"; then
	:
else
	script_dir="$(pwd)"
fi

bootstrap_log() {
	printf '[workstation-bootstrap] %s\n' "$*"
}

require_root_bootstrap() {
	if [[ "${EUID}" -ne 0 ]]; then
		bootstrap_log "Run as root, for example: curl ... | sudo -E bash"
		exit 1
	fi
}

apt_get_bootstrap() {
	apt-get -o DPkg::Lock::Timeout=600 "$@"
}

ensure_repo_checkout() {
	require_root_bootstrap
	bootstrap_log "Installing clone prerequisites"
	apt_get_bootstrap update
	apt_get_bootstrap install -y ca-certificates curl git

	if [[ -d "$WORKSTATION_REPO_DIR/.git" ]]; then
		bootstrap_log "Updating $WORKSTATION_REPO_DIR"
		git -C "$WORKSTATION_REPO_DIR" fetch --prune origin "$WORKSTATION_REPO_BRANCH"
		git -C "$WORKSTATION_REPO_DIR" checkout "$WORKSTATION_REPO_BRANCH"
		git -C "$WORKSTATION_REPO_DIR" pull --ff-only origin "$WORKSTATION_REPO_BRANCH"
	elif [[ -e "$WORKSTATION_REPO_DIR" ]]; then
		bootstrap_log "$WORKSTATION_REPO_DIR exists but is not a git checkout"
		exit 1
	else
		bootstrap_log "Cloning $WORKSTATION_REPO_URL"
		git clone --branch "$WORKSTATION_REPO_BRANCH" "$WORKSTATION_REPO_URL" "$WORKSTATION_REPO_DIR"
	fi

	exec env WORKSTATION_BOOTSTRAP_REEXEC=1 bash "$WORKSTATION_REPO_DIR/workstation/bootstrap.sh" "$@"
}

if [[ ! -f "$script_dir/modules/common.sh" ]]; then
	ensure_repo_checkout "$@"
fi

# shellcheck disable=SC1091
source "$script_dir/modules/common.sh"
# shellcheck disable=SC1091
source "$script_dir/lib/env.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/packages.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/infisical.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/tailscale.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/user.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/scripts.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/desktop.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/nomachine.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/github.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/syncthing.sh"
# shellcheck disable=SC1091
source "$script_dir/modules/rclone.sh"

main() {
	require_root
	install_base_packages
	install_infisical_cli
	fetch_infisical_env
	load_workstation_env
	set_workstation_defaults
	install_tailscale
	configure_tailscale
	configure_workstation_user
	install_helper_scripts "$script_dir/scripts" "$script_dir/lib"
	configure_github_access
	install_desktop
	install_nomachine
	configure_syncthing "$script_dir/systemd"
	configure_rclone_drive "$script_dir/systemd"
	log "Bootstrap complete"
	local user_name="${WORKSTATION_USER:-workstation}"
	log "Switch to workstation user with: sudo -iu $user_name"
	if id "$user_name" >/dev/null 2>&1; then
		sudo -H -u "$user_name" /usr/local/bin/workstation-info || true
	else
		/usr/local/bin/workstation-info || true
	fi
}

main "$@"
