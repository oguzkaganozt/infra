#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

strict_validation="${WORKSTATION_STRICT_VALIDATION:-}"
if [[ -z "$strict_validation" && "${CI:-}" == "true" ]]; then
	strict_validation=1
fi

require_tool() {
	local tool="$1"
	if command -v "$tool" >/dev/null 2>&1; then
		return 0
	fi

	if [[ "$strict_validation" == "1" ]]; then
		printf '%s is required but not installed.\n' "$tool" >&2
		exit 1
	fi

	printf '%s not installed; skipping.\n' "$tool" >&2
	return 1
}

documented_config_keys() {
	local file line
	for file in workstation/env.example workstation/cloud-init.example.yml; do
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ "$line" =~ ^[[:space:]]*#?[[:space:]]*([A-Z][A-Z0-9_]*)= ]]; then
				printf '%s\n' "${BASH_REMATCH[1]}"
			fi
		done <"$file"
	done

	# shellcheck disable=SC2016
	{ grep -hoE '`[A-Z][A-Z0-9_]+`' README.md workstation/README.md || true; } | tr -d '`'
}

validate_config_metadata() {
	# shellcheck disable=SC1091
	source workstation/lib/config.sh

	local failed=0 key
	for key in "${WORKSTATION_ENV_FILE_KEYS[@]}"; do
		if ! workstation_config_key_known "$key"; then
			printf 'Config allowlist key is missing from metadata: %s\n' "$key" >&2
			failed=1
		fi
	done

	for key in "${!WORKSTATION_CONFIG_DEFAULTS[@]}"; do
		if ! workstation_config_key_known "$key"; then
			printf 'Config default key is missing from metadata: %s\n' "$key" >&2
			failed=1
		fi
	done

	while IFS= read -r key; do
		[[ -n "$key" ]] || continue
		if ! workstation_config_key_known "$key"; then
			printf 'Documented config key is missing from metadata: %s\n' "$key" >&2
			failed=1
		fi
	done < <(documented_config_keys | sort -u)

	((failed == 0))
}

bash -n workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh
validate_config_metadata
workstation/scripts/test-source.sh

if require_tool shellcheck; then
	shellcheck workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh
fi

if require_tool shfmt; then
	shfmt -d workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh
fi

if require_tool actionlint; then
	actionlint
fi

if require_tool systemd-analyze; then
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' EXIT
	mount_stub="$tmp_dir/workstation-mount-drive"
	syncthing_stub="$tmp_dir/syncthing"
	printf '#!/usr/bin/env sh\nexit 0\n' >"$mount_stub"
	printf '#!/usr/bin/env sh\nexit 0\n' >"$syncthing_stub"
	chmod 0755 "$mount_stub" "$syncthing_stub"

	for unit in workstation/systemd/*.service workstation/systemd/*.timer; do
		[[ -e "$unit" ]] || continue
		out="$tmp_dir/$(basename "$unit")"
		while IFS= read -r line || [[ -n "$line" ]]; do
			line="${line//\/usr\/local\/bin\/workstation-mount-drive/$mount_stub}"
			line="${line//\/usr\/bin\/syncthing/$syncthing_stub}"
			printf '%s\n' "$line"
		done <"$unit" >"$out"
	done

	mapfile -t units < <(find "$tmp_dir" -maxdepth 1 -type f \( -name '*.service' -o -name '*.timer' \) -print)
	if ((${#units[@]} > 0)); then
		systemd-analyze --recursive-errors=no verify "${units[@]}"
	fi
fi

if require_tool cloud-init; then
	cloud-init schema --config-file workstation/cloud-init.example.yml
fi
