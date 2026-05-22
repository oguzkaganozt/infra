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

test_env_loading_and_defaults
test_cached_env_requires_explicit_flag
test_rclone_config_b64_cleanup
