#!/usr/bin/env bash

syncthing_home() {
	local user_name="${WORKSTATION_USER:-$(workstation_config_default WORKSTATION_USER)}"
	local user_home
	user_home="$(getent passwd "$user_name" | cut -d: -f6)"
	printf '%s' "${SYNCTHING_HOME:-$user_home/.local/state/syncthing}"
}

install_syncthing() {
	if command -v syncthing >/dev/null 2>&1; then
		log "Syncthing is already installed"
		return
	fi

	log "Installing Syncthing"
	ensure_apt_packages syncthing
}

configure_syncthing_workspace() {
	local user_name="${WORKSTATION_USER:-$(workstation_config_default WORKSTATION_USER)}"
	local workspace_dir="${WORKSPACE_DIR:-$(workstation_config_default WORKSPACE_DIR)}"
	local home_dir
	local created_workspace=0
	home_dir="$(syncthing_home)"

	if ! id "$user_name" >/dev/null 2>&1; then
		die "Workstation user does not exist: $user_name"
	fi

	log "Configuring Syncthing workspace for $user_name"
	if [[ ! -d "$workspace_dir" ]]; then
		mkdir -p "$workspace_dir"
		created_workspace=1
	fi
	mkdir -p "$home_dir"
	if [[ "$created_workspace" == "1" || "${WORKSPACE_CHOWN_RECURSIVE:-0}" == "1" ]]; then
		chown -R "$user_name:$user_name" "$workspace_dir"
	else
		chown "$user_name:$user_name" "$workspace_dir"
	fi
	chown -R "$user_name:$user_name" "$home_dir"
	sudo -H -u "$user_name" syncthing generate --home="$home_dir" --no-port-probing >/dev/null

	SYNCTHING_GUI_ADDRESS="${SYNCTHING_GUI_ADDRESS:-$(workstation_config_default SYNCTHING_GUI_ADDRESS)}"
	SYNCTHING_PEER_ADDRESS="${SYNCTHING_PEER_ADDRESS:-$(workstation_config_default SYNCTHING_PEER_ADDRESS)}"
	SYNCTHING_PEER_NAME="${SYNCTHING_PEER_NAME:-$(workstation_config_default SYNCTHING_PEER_NAME)}"
	SYNCTHING_RESCAN_INTERVAL="${SYNCTHING_RESCAN_INTERVAL:-$(workstation_config_default SYNCTHING_RESCAN_INTERVAL)}"
	export SYNCTHING_GUI_ADDRESS SYNCTHING_PEER_ADDRESS SYNCTHING_PEER_NAME SYNCTHING_RESCAN_INTERVAL

	SYNCTHING_HOME_DIR="$home_dir" python3 - <<'PY'
import os
import xml.etree.ElementTree as ET

home = os.environ["SYNCTHING_HOME_DIR"]
config_path = os.path.join(home, "config.xml")
workspace_dir = os.environ["WORKSPACE_DIR"]
folder_id = os.environ["SYNCTHING_FOLDER_ID"]
folder_label = os.environ["SYNCTHING_FOLDER_LABEL"]
peer_ids_raw = os.environ.get("SYNCTHING_PEER_DEVICE_IDS") or os.environ.get("SYNCTHING_PEER_DEVICE_ID", "")
peer_ids = [peer.strip() for peer in peer_ids_raw.replace(";", ",").split(",") if peer.strip()]
peer_name = os.environ["SYNCTHING_PEER_NAME"]
peer_address = os.environ["SYNCTHING_PEER_ADDRESS"]
role = os.environ["WORKSTATION_ROLE"]

tree = ET.parse(config_path)
root = tree.getroot()

gui = root.find("gui")
if gui is not None:
    address = gui.find("address")
    if address is None:
        address = ET.SubElement(gui, "address")
    address.text = os.environ["SYNCTHING_GUI_ADDRESS"]

local_device = root.find("device")
if local_device is None or not local_device.get("id"):
    raise SystemExit("Syncthing config has no local device ID")
local_id = local_device.get("id")
local_device.set("name", os.environ.get("SYNCTHING_DEVICE_NAME", role))

folder = None
for existing in root.findall("folder"):
    if existing.get("id") == folder_id:
        folder = existing
        break

if folder is None:
    folder = ET.Element("folder", {"id": folder_id})
    root.insert(0, folder)

folder.set("label", folder_label)
folder.set("path", workspace_dir)
folder.set("type", "sendreceive")
folder.set("rescanIntervalS", os.environ["SYNCTHING_RESCAN_INTERVAL"])
folder.set("fsWatcherEnabled", "true")
folder.set("fsWatcherDelayS", "10")
folder.set("ignorePerms", "false")

if folder.find("filesystemType") is None:
    ET.SubElement(folder, "filesystemType").text = "basic"

folder_device_ids = {device.get("id") for device in folder.findall("device") if device.get("id")}
for device_id in [local_id, *peer_ids]:
    if device_id not in folder_device_ids:
        ET.SubElement(folder, "device", {"id": device_id, "introducedBy": ""})
        folder_device_ids.add(device_id)

existing_device_ids = {device.get("id") for device in root.findall("device") if device.get("id")}
for index, peer_id in enumerate(peer_ids, start=1):
    if peer_id in existing_device_ids:
        continue
    peer = ET.Element(
        "device",
        {
            "id": peer_id,
            "name": peer_name if len(peer_ids) == 1 else f"{peer_name}-{index}",
            "compression": "metadata",
            "introducer": "true" if role == "workstation" else "false",
            "skipIntroductionRemovals": "false",
            "introducedBy": "",
        },
    )
    ET.SubElement(peer, "address").text = peer_address
    root.insert(index, peer)
    existing_device_ids.add(peer_id)

ET.indent(tree, space="    ")
tree.write(config_path, encoding="utf-8", xml_declaration=True)
PY

	chown "$user_name:$user_name" "$home_dir/config.xml"
}

install_syncthing_service() {
	local systemd_dir="$1"
	local user_name="${WORKSTATION_USER:-$(workstation_config_default WORKSTATION_USER)}"
	local home_dir
	home_dir="$(syncthing_home)"

	log "Installing Syncthing systemd service"
	install -m 0644 "$systemd_dir/workstation-syncthing.service" /etc/systemd/system/workstation-syncthing.service
	sed -i \
		-e "s|^User=.*|User=$user_name|" \
		-e "s|^ExecStart=.*|ExecStart=/usr/bin/syncthing serve --no-browser --home=$home_dir|" \
		/etc/systemd/system/workstation-syncthing.service

	systemctl daemon-reload
	systemctl enable --now workstation-syncthing.service
}

configure_syncthing() {
	local systemd_dir="$1"

	install_syncthing
	configure_syncthing_workspace
	install_syncthing_service "$systemd_dir"
}
