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

if [[ -z "${WORKSTATION_USER:-}" ]]; then
	current_user="$(id -un 2>/dev/null || true)"
	if [[ -n "$current_user" && "$current_user" != "root" && "$current_user" != "ubuntu" ]]; then
		WORKSTATION_USER="$current_user"
	else
		WORKSTATION_USER="workstation"
	fi
fi

tailscale_ip() {
	if command -v tailscale >/dev/null 2>&1; then
		tailscale ip -4 2>/dev/null | awk 'NR == 1 {print; exit}'
	fi
}

service_state() {
	if command -v systemctl >/dev/null 2>&1; then
		systemctl is-active "$1" 2>/dev/null || true
	fi
}

endpoint_host="${TS_HOSTNAME:-}"
tail_ip="$(tailscale_ip || true)"
if [[ -z "$endpoint_host" ]]; then
	endpoint_host="$tail_ip"
fi

printf 'Workstation\n'
printf '  Hostname: %s\n' "$(hostname)"
printf '  Tailscale name: %s\n' "${TS_HOSTNAME:-unknown}"
printf '  Tailscale IP: %s\n' "${tail_ip:-unknown}"
printf '  Workspace: %s\n' "$WORKSPACE_DIR"
printf '  Drive: %s\n' "$DRIVE_DIR"
printf '  Role: %s\n' "$WORKSTATION_ROLE"
printf '  Syncthing: %s\n' "$(service_state workstation-syncthing.service)"
printf '  Drive mount: %s\n' "$(service_state drive-mount.service)"

printf '\nEndpoints\n'
if [[ -n "$endpoint_host" ]]; then
	printf '  SSH: ssh %s@%s\n' "$WORKSTATION_USER" "$endpoint_host"
	printf '  NoMachine: %s:4000\n' "$endpoint_host"
	printf '  Jupyter: http://%s:8888\n' "$endpoint_host"
	printf '  Gradio: http://%s:7860\n' "$endpoint_host"
	printf '  Dev server: http://%s:3000\n' "$endpoint_host"
	printf '  FastAPI: http://%s:8000\n' "$endpoint_host"
	printf '  Web app: http://%s:8080\n' "$endpoint_host"
else
	printf '  Tailscale is not connected yet.\n'
fi

if [[ -n "${PUBLIC_IPADDR:-}" && -n "${VAST_TCP_PORT_4000:-}" ]]; then
	printf '\nProvider Fallback\n'
	printf '  Vast NoMachine: %s:%s\n' "$PUBLIC_IPADDR" "$VAST_TCP_PORT_4000"
	[[ -n "${VAST_TCP_PORT_22:-}" ]] && printf '  Vast SSH: ssh root@%s -p %s\n' "$PUBLIC_IPADDR" "$VAST_TCP_PORT_22"
fi
