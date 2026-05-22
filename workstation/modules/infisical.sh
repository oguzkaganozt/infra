#!/usr/bin/env bash

install_infisical_cli() {
	if command -v infisical >/dev/null 2>&1; then
		log "Infisical CLI is already installed"
		return
	fi

	log "Installing Infisical CLI"
	curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash
	apt_get update
	apt_get install -y infisical
}

fetch_infisical_env() {
	INFISICAL_API_URL="${INFISICAL_API_URL:-$(workstation_config_default INFISICAL_API_URL)}"
	INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-$(workstation_config_default INFISICAL_SECRET_PATH)}"
	export INFISICAL_API_URL INFISICAL_DISABLE_UPDATE_CHECK=true

	log "Fetching workstation secrets from Infisical"
	local token
	token="${INFISICAL_TOKEN:-}"

	if [[ -z "$token" ]]; then
		INFISICAL_ENV="${INFISICAL_ENV:-$(workstation_config_default INFISICAL_ENV)}"

		if [[ -z "${INFISICAL_CLIENT_ID:-}" || -z "${INFISICAL_CLIENT_SECRET:-}" || -z "${INFISICAL_PROJECT_ID:-}" ]]; then
			if [[ "${WORKSTATION_ALLOW_CACHED_ENV:-0}" == "1" && -f "$WORKSTATION_ENV_FILE" ]]; then
				log "Infisical bootstrap credentials are missing; WORKSTATION_ALLOW_CACHED_ENV=1, using existing $WORKSTATION_ENV_FILE"
				return
			fi

			die "Set INFISICAL_TOKEN, or set INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, and INFISICAL_PROJECT_ID. To reuse existing $WORKSTATION_ENV_FILE, set WORKSTATION_ALLOW_CACHED_ENV=1."
		fi

		token="$(infisical login \
			--method=universal-auth \
			--client-id="$INFISICAL_CLIENT_ID" \
			--client-secret="$INFISICAL_CLIENT_SECRET" \
			--silent \
			--plain)"
	fi

	local export_args=(
		--format=dotenv
		--output-file="$WORKSTATION_ENV_FILE"
	)

	if [[ -n "${INFISICAL_ENV:-}" ]]; then
		export_args+=(--env="$INFISICAL_ENV")
	fi

	if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
		export_args+=(--projectId="$INFISICAL_PROJECT_ID")
	fi

	if [[ -n "${INFISICAL_SECRET_PATH:-}" ]]; then
		export_args+=(--path="$INFISICAL_SECRET_PATH")
	fi

	local old_umask
	old_umask="$(umask)"
	umask 077
	INFISICAL_TOKEN="$token" infisical export "${export_args[@]}"
	umask "$old_umask"

	{
		printf '\n'
		printf 'INFISICAL_API_URL=%q\n' "$INFISICAL_API_URL"
		[[ -n "${INFISICAL_ENV:-}" ]] && printf 'INFISICAL_ENV=%q\n' "$INFISICAL_ENV"
		printf 'INFISICAL_SECRET_PATH=%q\n' "$INFISICAL_SECRET_PATH"
	} >>"$WORKSTATION_ENV_FILE"

	chmod 0600 "$WORKSTATION_ENV_FILE"
}
