#!/usr/bin/env bash

install_tailscale() {
	if command -v tailscale >/dev/null 2>&1; then
		log "Tailscale is already installed"
	else
		log "Installing Tailscale"
		curl -fsSL https://tailscale.com/install.sh | sh
	fi

	systemctl enable --now tailscaled
}

configure_tailscale() {
	if [[ -z "${TS_AUTHKEY:-}" ]]; then
		log "TS_AUTHKEY is missing; skipping Tailscale login"
		return
	fi

	local args=()
	if tailscale ip -4 >/dev/null 2>&1; then
		log "Reconciling Tailscale settings"
	else
		log "Connecting Tailscale"
		args+=(--authkey "$TS_AUTHKEY")
	fi

	if [[ -n "${TS_HOSTNAME:-}" ]]; then
		args+=(--hostname "$TS_HOSTNAME")
	fi

	if [[ "${TS_ENABLE_SSH:-$(workstation_config_default TS_ENABLE_SSH)}" == "1" ]]; then
		args+=(--ssh)
	fi

	if [[ -n "${TS_EXTRA_ARGS:-}" ]]; then
		local extra_args=()
		read -r -a extra_args <<<"$TS_EXTRA_ARGS"
		args+=("${extra_args[@]}")
	fi

	tailscale up "${args[@]}"
}
