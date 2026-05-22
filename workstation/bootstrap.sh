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

print_usage() {
	cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
  --role workstation|base        Machine role. Default: workstation.
  --headless                     Disable desktop and NoMachine.
  --gui                          Enable desktop and NoMachine.
  --desktop | --no-desktop       Enable or disable desktop packages.
  --nomachine | --no-nomachine   Enable or disable NoMachine.
  --hostname NAME                Tailscale hostname.
  --user NAME                    Workstation login user. Default: workstation.
  --secret-path PATH             Infisical secret path. Default: /.
  --infisical-api-url URL        Infisical API URL.
  --infisical-env NAME           Infisical environment. Default: prod.
  --branch NAME                  Repository branch. Default: main.
  --repo-dir PATH                Repository checkout directory.
  --repo-url URL                 Repository URL.
  --allow-cached-env             Reuse /etc/workstation.env when Infisical credentials are missing.
  --chown-workspace              Recursively chown an existing workspace directory.
  --syncthing-peer DEVICE_ID     Add a Syncthing peer device ID. Repeatable.
  --rclone-remote NAME           rclone remote name. Default: gdrive.
  --drive-path PATH              Path within the rclone remote to mount.
  --workspace-dir PATH           Local workspace directory. Default: /workspace.
  --drive-dir PATH               Local drive mount directory. Default: /drive.
  -h, --help                     Show this help.
EOF
}

require_arg_value() {
	local flag="$1"
	local value="${2:-}"
	if [[ -z "$value" || "$value" == --* ]]; then
		bootstrap_log "$flag requires a value"
		exit 1
	fi
}

set_cli_override() {
	local key="$1"
	local value="$2"
	local storage_key="WORKSTATION_CLI_$key"

	printf -v "$key" '%s' "$value"
	export "${key?}"
	printf -v "$storage_key" '%s' "$value"
	export "${storage_key?}"

	case " ${WORKSTATION_CLI_OVERRIDE_KEYS:-} " in
	*" $key "*) ;;
	*) WORKSTATION_CLI_OVERRIDE_KEYS="${WORKSTATION_CLI_OVERRIDE_KEYS:-}${WORKSTATION_CLI_OVERRIDE_KEYS:+ }$key" ;;
	esac
	export WORKSTATION_CLI_OVERRIDE_KEYS
}

append_cli_csv_override() {
	local key="$1"
	local value="$2"
	local current="${!key:-}"
	if [[ -n "$current" ]]; then
		set_cli_override "$key" "$current,$value"
	else
		set_cli_override "$key" "$value"
	fi
}

parse_bootstrap_args() {
	local arg value
	while (($# > 0)); do
		arg="$1"
		case "$arg" in
		-h | --help)
			print_usage
			exit 0
			;;
		--role)
			require_arg_value "$arg" "${2:-}"
			set_cli_override WORKSTATION_ROLE "$2"
			shift 2
			;;
		--role=*)
			value="${arg#*=}"
			require_arg_value --role "$value"
			set_cli_override WORKSTATION_ROLE "$value"
			shift
			;;
		--headless)
			set_cli_override INSTALL_DESKTOP 0
			set_cli_override INSTALL_NOMACHINE 0
			shift
			;;
		--gui)
			set_cli_override INSTALL_DESKTOP 1
			set_cli_override INSTALL_NOMACHINE 1
			shift
			;;
		--desktop)
			set_cli_override INSTALL_DESKTOP 1
			shift
			;;
		--no-desktop)
			set_cli_override INSTALL_DESKTOP 0
			shift
			;;
		--nomachine)
			set_cli_override INSTALL_NOMACHINE 1
			shift
			;;
		--no-nomachine)
			set_cli_override INSTALL_NOMACHINE 0
			shift
			;;
		--allow-cached-env)
			set_cli_override WORKSTATION_ALLOW_CACHED_ENV 1
			shift
			;;
		--chown-workspace)
			set_cli_override WORKSPACE_CHOWN_RECURSIVE 1
			shift
			;;
		--hostname | --user | --secret-path | --infisical-api-url | --infisical-env | --branch | --repo-dir | --repo-url | --syncthing-peer | --rclone-remote | --drive-path | --workspace-dir | --drive-dir)
			require_arg_value "$arg" "${2:-}"
			value="$2"
			case "$arg" in
			--hostname) set_cli_override TS_HOSTNAME "$value" ;;
			--user) set_cli_override WORKSTATION_USER "$value" ;;
			--secret-path) set_cli_override INFISICAL_SECRET_PATH "$value" ;;
			--infisical-api-url) set_cli_override INFISICAL_API_URL "$value" ;;
			--infisical-env) set_cli_override INFISICAL_ENV "$value" ;;
			--branch) set_cli_override WORKSTATION_REPO_BRANCH "$value" ;;
			--repo-dir) set_cli_override WORKSTATION_REPO_DIR "$value" ;;
			--repo-url) set_cli_override WORKSTATION_REPO_URL "$value" ;;
			--syncthing-peer) append_cli_csv_override SYNCTHING_PEER_DEVICE_IDS "$value" ;;
			--rclone-remote) set_cli_override RCLONE_REMOTE "$value" ;;
			--drive-path) set_cli_override RCLONE_REMOTE_PATH "$value" ;;
			--workspace-dir) set_cli_override WORKSPACE_DIR "$value" ;;
			--drive-dir) set_cli_override DRIVE_DIR "$value" ;;
			esac
			shift 2
			;;
		--hostname=* | --user=* | --secret-path=* | --infisical-api-url=* | --infisical-env=* | --branch=* | --repo-dir=* | --repo-url=* | --syncthing-peer=* | --rclone-remote=* | --drive-path=* | --workspace-dir=* | --drive-dir=*)
			value="${arg#*=}"
			require_arg_value "${arg%%=*}" "$value"
			case "${arg%%=*}" in
			--hostname) set_cli_override TS_HOSTNAME "$value" ;;
			--user) set_cli_override WORKSTATION_USER "$value" ;;
			--secret-path) set_cli_override INFISICAL_SECRET_PATH "$value" ;;
			--infisical-api-url) set_cli_override INFISICAL_API_URL "$value" ;;
			--infisical-env) set_cli_override INFISICAL_ENV "$value" ;;
			--branch) set_cli_override WORKSTATION_REPO_BRANCH "$value" ;;
			--repo-dir) set_cli_override WORKSTATION_REPO_DIR "$value" ;;
			--repo-url) set_cli_override WORKSTATION_REPO_URL "$value" ;;
			--syncthing-peer) append_cli_csv_override SYNCTHING_PEER_DEVICE_IDS "$value" ;;
			--rclone-remote) set_cli_override RCLONE_REMOTE "$value" ;;
			--drive-path) set_cli_override RCLONE_REMOTE_PATH "$value" ;;
			--workspace-dir) set_cli_override WORKSPACE_DIR "$value" ;;
			--drive-dir) set_cli_override DRIVE_DIR "$value" ;;
			esac
			shift
			;;
		--)
			shift
			break
			;;
		*)
			bootstrap_log "Unknown option: $arg"
			bootstrap_log "Run with --help for usage."
			exit 1
			;;
		esac
	done

	case "${WORKSTATION_ROLE:-}" in
	"" | workstation | base) ;;
	*)
		bootstrap_log "--role must be workstation or base"
		exit 1
		;;
	esac
}

apply_cli_overrides() {
	local key storage_key
	for key in ${WORKSTATION_CLI_OVERRIDE_KEYS:-}; do
		storage_key="WORKSTATION_CLI_$key"
		if [[ -v "$storage_key" ]]; then
			printf -v "$key" '%s' "${!storage_key}"
			export "${key?}"
		fi
	done
}

persist_cli_overrides() {
	[[ -n "${WORKSTATION_CLI_OVERRIDE_KEYS:-}" ]] || return 0
	local env_file="${WORKSTATION_ENV_FILE:-/etc/workstation.env}"
	local tmp_file key storage_key line

	tmp_file="$(mktemp)"
	if [[ -f "$env_file" ]]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			local keep_line=1
			for key in ${WORKSTATION_CLI_OVERRIDE_KEYS:-}; do
				workstation_env_key_allowed "$key" || continue
				if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?${key}= ]]; then
					keep_line=0
					break
				fi
			done
			[[ "$keep_line" == "1" ]] && printf '%s\n' "$line"
		done <"$env_file" >"$tmp_file"
	fi

	for key in ${WORKSTATION_CLI_OVERRIDE_KEYS:-}; do
		workstation_env_key_allowed "$key" || continue
		storage_key="WORKSTATION_CLI_$key"
		[[ -v "$storage_key" ]] || continue
		printf '%s=%q\n' "$key" "${!storage_key}" >>"$tmp_file"
	done

	install -m 0600 "$tmp_file" "$env_file"
	rm -f "$tmp_file"
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

if [[ "${WORKSTATION_BOOTSTRAP_ARGS_PARSED:-0}" != "1" ]]; then
	parse_bootstrap_args "$@"
	export WORKSTATION_BOOTSTRAP_ARGS_PARSED=1
fi

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
	apply_cli_overrides
	persist_cli_overrides
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

if [[ "${WORKSTATION_BOOTSTRAP_TEST_SOURCE:-0}" != "1" ]]; then
	main "$@"
fi
