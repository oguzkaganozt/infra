#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/workstation.env}"
if [[ -f /etc/environment ]]; then
  set -a
  # shellcheck disable=SC1091
  source /etc/environment
  set +a
fi
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
RESTIC_TAG="${RESTIC_TAG:-workspace}"
NOMACHINE_USER="${NOMACHINE_USER:-workstation}"

tailscale_ip() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale ip -4 2>/dev/null | awk 'NR == 1 {print; exit}'
  fi
}

timer_state() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active workspace-backup.timer 2>/dev/null || true
  fi
}

latest_snapshot() {
  if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]] || ! command -v restic >/dev/null 2>&1; then
    return
  fi

  restic snapshots --tag "$RESTIC_TAG" 2>/dev/null | awk '/^[0-9a-f]/ {line=$0} END {print line}'
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
printf '  Backup timer: %s\n' "$(timer_state)"

snapshot="$(latest_snapshot)"
if [[ -n "$snapshot" ]]; then
  printf '  Latest snapshot: %s\n' "$snapshot"
else
  printf '  Latest snapshot: unknown\n'
fi

printf '\nEndpoints\n'
if [[ -n "$endpoint_host" ]]; then
  printf '  SSH: ssh %s@%s\n' "$NOMACHINE_USER" "$endpoint_host"
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
