#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
	printf 'test-source: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	[[ "$actual" == "$expected" ]] || fail "$message: expected '$expected', got '$actual'"
}

test_env_loading_and_defaults() {
	local env_file="$tmp_dir/workstation.env"
	cat >"$env_file" <<'EOF'
WORKSPACE_DIR='/tmp/workspace'
RCLONE_REMOTE="drive"
UNSUPPORTED_KEY='ignored'
EOF

	export WORKSTATION_ENV_FILE="$env_file"
	# shellcheck disable=SC1091
	source workstation/lib/env.sh
	load_workstation_env "$WORKSTATION_ENV_FILE"
	set_workstation_defaults
	assert_eq /tmp/workspace "$WORKSPACE_DIR" 'loads quoted env values'
	assert_eq drive "$RCLONE_REMOTE" 'loads double-quoted env values'
	assert_eq /drive "$DRIVE_DIR" 'sets default drive directory'
	[[ -z "${UNSUPPORTED_KEY:-}" ]] || fail 'unsupported env key was imported'
}

test_cached_env_requires_explicit_flag() {
	local env_file="$tmp_dir/cached.env"
	printf 'TS_AUTHKEY=x\n' >"$env_file"

	if bash -c '
		set -euo pipefail
		# shellcheck disable=SC1091
		source workstation/modules/common.sh
		# shellcheck disable=SC1091
		source workstation/lib/env.sh
		# shellcheck disable=SC1091
		source workstation/modules/infisical.sh
		unset INFISICAL_TOKEN INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET INFISICAL_PROJECT_ID WORKSTATION_ALLOW_CACHED_ENV
		export WORKSTATION_ENV_FILE="$1"
		fetch_infisical_env >/dev/null 2>&1
	' _ "$env_file"; then
		fail 'cached env was reused without WORKSTATION_ALLOW_CACHED_ENV=1'
	fi

	bash -c '
		set -euo pipefail
		# shellcheck disable=SC1091
		source workstation/modules/common.sh
		# shellcheck disable=SC1091
		source workstation/lib/env.sh
		# shellcheck disable=SC1091
		source workstation/modules/infisical.sh
		unset INFISICAL_TOKEN INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET INFISICAL_PROJECT_ID
		export WORKSTATION_ENV_FILE="$1" WORKSTATION_ALLOW_CACHED_ENV=1
		fetch_infisical_env >/dev/null
	' _ "$env_file"
}

test_rclone_config_b64_cleanup() {
	local env_file="$tmp_dir/rclone.env"
	cat >"$env_file" <<'EOF'
RCLONE_CONFIG_B64=secret
RCLONE_REMOTE=gdrive
EOF

	export WORKSTATION_ENV_FILE="$env_file"
	# shellcheck disable=SC1091
	source workstation/lib/env.sh
	# shellcheck disable=SC1091
	source workstation/modules/rclone.sh
	remove_rclone_config_b64_from_env

	if grep -q '^RCLONE_CONFIG_B64=' "$env_file"; then
		fail 'RCLONE_CONFIG_B64 remained in env file after cleanup'
	fi
	grep -q '^RCLONE_REMOTE=gdrive$' "$env_file" || fail 'rclone cleanup removed unrelated env key'
}

test_bootstrap_cli_overrides() {
	# shellcheck disable=SC2030
	(
		set -euo pipefail
		export WORKSTATION_BOOTSTRAP_TEST_SOURCE=1
		# shellcheck disable=SC1091
		source workstation/bootstrap.sh
		parse_bootstrap_args \
			--role base \
			--headless \
			--hostname workspace-vps \
			--infisical-api-url https://infisical.example.com \
			--secret-path /vps \
			--branch test-branch \
			--repo-dir /tmp/workstation-infra \
			--allow-cached-env \
			--chown-workspace \
			--syncthing-peer peer-one \
			--syncthing-peer peer-two \
			--rclone-remote drive \
			--drive-path datasets \
			--workspace-dir /ws \
			--drive-dir /mnt/drive

		WORKSTATION_ROLE=workstation
		INSTALL_DESKTOP=1
		INSTALL_NOMACHINE=1
		TS_HOSTNAME=wrong-hostname
		SYNCTHING_PEER_DEVICE_IDS=wrong-peer
		apply_cli_overrides

		assert_eq base "$WORKSTATION_ROLE" 'CLI role overrides env file values'
		assert_eq 0 "$INSTALL_DESKTOP" 'headless disables desktop'
		assert_eq 0 "$INSTALL_NOMACHINE" 'headless disables NoMachine'
		assert_eq workspace-vps "$TS_HOSTNAME" 'CLI hostname overrides env file values'
		assert_eq https://infisical.example.com "$INFISICAL_API_URL" 'CLI Infisical API URL is applied'
		assert_eq /vps "$INFISICAL_SECRET_PATH" 'CLI secret path is applied'
		assert_eq test-branch "$WORKSTATION_REPO_BRANCH" 'CLI branch is applied'
		assert_eq /tmp/workstation-infra "$WORKSTATION_REPO_DIR" 'CLI repo dir is applied'
		assert_eq 1 "$WORKSTATION_ALLOW_CACHED_ENV" 'cached env flag is applied'
		assert_eq 1 "$WORKSPACE_CHOWN_RECURSIVE" 'workspace chown flag is applied'
		assert_eq peer-one,peer-two "$SYNCTHING_PEER_DEVICE_IDS" 'repeatable Syncthing peer flags append'
		assert_eq drive "$RCLONE_REMOTE" 'CLI rclone remote is applied'
		assert_eq datasets "$RCLONE_REMOTE_PATH" 'CLI drive path is applied'
		assert_eq /ws "$WORKSPACE_DIR" 'CLI workspace dir is applied'
		assert_eq /mnt/drive "$DRIVE_DIR" 'CLI drive dir is applied'
	)
}

test_bootstrap_reexec_does_not_reparse_args() {
	bash -c '
		set -euo pipefail
		export WORKSTATION_BOOTSTRAP_TEST_SOURCE=1
		export WORKSTATION_BOOTSTRAP_ARGS_PARSED=1
		export SYNCTHING_PEER_DEVICE_IDS=peer-one
		# shellcheck disable=SC1091
		source workstation/bootstrap.sh --syncthing-peer peer-two
		[[ "$SYNCTHING_PEER_DEVICE_IDS" == peer-one ]]
	'
}

test_tailscale_preserves_connected_node() {
	local bin_dir="$tmp_dir/bin"
	local calls_file="$tmp_dir/tailscale-calls"
	mkdir -p "$bin_dir"
	cat >"$bin_dir/tailscale" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TAILSCALE_CALLS_FILE"
if [[ "$1" == "ip" ]]; then
	printf '100.64.0.1\n'
	exit 0
fi
if [[ "$1" == "up" ]]; then
	exit 1
fi
EOF
	chmod 0755 "$bin_dir/tailscale"

	(
		set -euo pipefail
		export PATH="$bin_dir:$PATH"
		export TAILSCALE_CALLS_FILE="$calls_file"
		export TS_AUTHKEY=test-auth-key
		# shellcheck disable=SC1091
		source workstation/modules/common.sh
		# shellcheck disable=SC1091
		source workstation/lib/env.sh
		# shellcheck disable=SC1091
		source workstation/modules/tailscale.sh
		configure_tailscale >/dev/null
	)

	grep -q '^ip -4$' "$calls_file" || fail 'connected Tailscale state was not checked'
	if grep -q '^up ' "$calls_file"; then
		fail 'bootstrap tried to run tailscale up on an already connected node'
	fi
}

test_env_loading_and_defaults
test_cached_env_requires_explicit_flag
test_rclone_config_b64_cleanup
test_bootstrap_cli_overrides
test_bootstrap_reexec_does_not_reparse_args
test_tailscale_preserves_connected_node
