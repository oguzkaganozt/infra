#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

bash -n workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh
else
	printf 'shellcheck not installed; skipping.\n' >&2
fi

if command -v shfmt >/dev/null 2>&1; then
	shfmt -d workstation/bootstrap.sh workstation/modules/*.sh workstation/scripts/*.sh workstation/lib/*.sh
else
	printf 'shfmt not installed; skipping.\n' >&2
fi

if command -v systemd-analyze >/dev/null 2>&1; then
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
else
	printf 'systemd-analyze not installed; skipping.\n' >&2
fi
