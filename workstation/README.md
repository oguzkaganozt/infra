# workstation

Vendor-agnostic bootstrap for Ubuntu cloud workstations and the persistent sync node.

The target is any fresh Ubuntu 22.04 or 24.04 VM from any provider. The bootstrap fetches secrets from Infisical, joins Tailscale, configures a workstation user, optionally installs XFCE/NoMachine, syncs `/workspace` with Syncthing, and mounts Google Drive at `/drive` with rclone.

## Stack

| Component | Purpose |
|---|---|
| Infisical | Secrets source of truth |
| Tailscale | Stable private networking and SSH |
| Syncthing | Smooth machine-to-machine `/workspace` sync |
| rclone | Google Drive mount at `/drive` |
| XFCE | Lightweight desktop environment for server images |
| NoMachine | Remote GUI desktop on port `4000` |
| systemd | Syncthing and rclone service management |

## Storage Model

Use `/workspace` for active development:

```text
/workspace
```

This is a normal local filesystem, so Docker builds, git, package installs, file watchers, and editors behave normally. Syncthing keeps it synchronized with your persistent VPS and other workstations.

Use `/drive` for Google Drive files:

```text
/drive
```

This is an rclone mount of Google Drive. Use it for datasets, model weights, checkpoints, exports, archives, and files you want to browse from phone, tablet, desktop, or web. Do not use `/drive` as an active build/database/package-install directory.

Recommended topology:

```text
Persistent VPS
  /workspace  Syncthing canonical peer
  /drive      Google Drive mount

Disposable workstation
  /workspace  local disk + Syncthing peer
  /drive      Google Drive mount
```

## Bootstrap

Simplest path: create an Infisical service token scoped to `prod:/` with read access, then set only this on the VM or in the provider startup environment:

```bash
export INFISICAL_TOKEN='<infisical-service-token>'
```

Then run a workstation with the opinionated defaults:

```bash
curl -fsSL https://raw.githubusercontent.com/oguzkaganozt/infra/main/workstation/bootstrap.sh | sudo -E bash
```

If the provider supports cloud-init, use `workstation/cloud-init.example.yml` as the starting user-data template instead of the manual curl command.

Run the persistent sync VPS with flags instead of storing machine intent in Infisical:

```bash
curl -fsSL https://raw.githubusercontent.com/oguzkaganozt/infra/main/workstation/bootstrap.sh | sudo -E bash -s -- --role base --hostname workspace-vps
```

Run a disposable workstation and pair it with the VPS Syncthing device ID:

```bash
curl -fsSL https://raw.githubusercontent.com/oguzkaganozt/infra/main/workstation/bootstrap.sh | sudo -E bash -s -- --role workstation --hostname gpu-workstation --syncthing-peer '<vps-syncthing-device-id>'
```

Common bootstrap flags:

```bash
--role workstation|base
--hostname NAME
--headless
--gui
--secret-path /
--infisical-env prod
--branch main
--repo-dir /opt/workstation-infra
--allow-cached-env
--syncthing-peer DEVICE_ID
--rclone-remote gdrive
--drive-path PATH
```

For a cheaper headless workstation, skip the GUI packages:

```bash
curl -fsSL https://raw.githubusercontent.com/oguzkaganozt/infra/main/workstation/bootstrap.sh | sudo -E bash -s -- --headless
```

Machine identity auth is also supported if you prefer it over service tokens:

```bash
export INFISICAL_CLIENT_ID='<machine-identity-client-id>'
export INFISICAL_CLIENT_SECRET='<machine-identity-client-secret>'
export INFISICAL_PROJECT_ID='<project-id>'
export INFISICAL_ENV='prod'
```

## Infisical Secrets

Create one Infisical project, for example `workstation`, with a `prod` environment. Add a read-only service token scoped to `prod:/` for the simplest one-variable bootstrap.

Store only the needed secrets in Infisical:

```bash
TS_AUTHKEY='<tailscale-auth-key>'
RCLONE_CONFIG_B64='<base64-encoded-rclone.conf>'
WORKSTATION_PASSWORD='<strong-nomachine-password>'
```

Create `RCLONE_CONFIG_B64` from a working rclone Google Drive config:

```bash
base64 -w0 ~/.config/rclone/rclone.conf
```

Everything else has code defaults or bootstrap flags. `workstation/lib/config.sh` is the source of truth for supported variables and defaults.

| Setting | Default |
|---|---|
| `WORKSTATION_ROLE` | `workstation` |
| `WORKSPACE_DIR` | `/workspace` |
| `DRIVE_DIR` | `/drive` |
| `SYNCTHING_FOLDER_ID` | `workspace` |
| `SYNCTHING_FOLDER_LABEL` | `workspace` |
| `SYNCTHING_PEER_ADDRESS` | `dynamic` |
| `WORKSPACE_CHOWN_RECURSIVE` | `0` |
| `WORKSTATION_USER` | `workstation` |
| `RCLONE_REMOTE` | `gdrive` |
| `RCLONE_CONFIG` | `/etc/workstation-rclone/rclone.conf` |
| `RCLONE_REMOTE_PATH` | empty, mount the whole remote |
| `RCLONE_VFS_CACHE_DIR` | `/var/cache/workstation-rclone` |
| `RCLONE_VFS_CACHE_MAX_SIZE` | `50G` |
| `RCLONE_VFS_CACHE_MAX_AGE` | `24h` |
| `RCLONE_DIR_CACHE_TIME` | `1h` |
| `RCLONE_POLL_INTERVAL` | `1m` |
| `NOMACHINE_DEB_URL` | `https://www.nomachine.com/free/linux/64/deb` |
| `NOMACHINE_INSTALL_TIMEOUT` | `1800` |
| `INSTALL_DESKTOP` | `1` |
| `DESKTOP_PACKAGES` | `xfce4 xfce4-goodies dbus-x11 x11-xserver-utils` |
| `INSTALL_NOMACHINE` | `1` |
| `TS_ENABLE_SSH` | `1` |
| `WORKSTATION_ALLOW_CACHED_ENV` | `0` |

For the persistent VPS, pass:

```bash
--role base
```

`base` skips desktop and NoMachine by default. Pass `--gui`, `--desktop`, or `--nomachine` only if you intentionally want GUI access on the VPS.

For each disposable workstation, pass `--syncthing-peer` with the VPS Syncthing device ID after bootstrapping the VPS. Run this on the VPS to get it:

```bash
workstation-sync-info
```

You can also pass `--syncthing-peer` on the VPS with workstation device IDs for fully automatic pairing, or add workstations from the Syncthing web UI over a Tailscale SSH tunnel.

For GitHub access, add one optional secret:

```bash
GITHUB_TOKEN='<fine-grained-github-token>'
```

When present, bootstrap logs in with `gh auth login --with-token` as `WORKSTATION_USER` and runs `gh auth setup-git`, so HTTPS `git clone`, `git pull`, and `git push` work through GitHub CLI credentials.

The provider only sees the Infisical bootstrap token or machine identity credentials. Real workstation secrets are fetched at bootstrap and written root-only to `/etc/workstation.env`. Bootstrap will not reuse that cached file unless `WORKSTATION_ALLOW_CACHED_ENV=1` is set, so missing or expired Infisical credentials fail clearly by default.

`RCLONE_CONFIG_B64` is decoded into `RCLONE_CONFIG` and then removed from `/etc/workstation.env`; the decoded rclone config file remains the durable secret artifact.

## Access

Use Tailscale endpoints instead of provider public IPs or random port mappings:

```text
SSH: ssh <workstation-user>@<tailscale-hostname-or-ip>
NoMachine: <tailscale-hostname-or-ip>:4000
Syncthing GUI: ssh -L 8384:127.0.0.1:8384 <workstation-user>@<tailscale-hostname-or-ip>
Jupyter: http://<tailscale-hostname-or-ip>:8888
Gradio: http://<tailscale-hostname-or-ip>:7860
Dev server: http://<tailscale-hostname-or-ip>:3000
FastAPI: http://<tailscale-hostname-or-ip>:8000
Web app: http://<tailscale-hostname-or-ip>:8080
```

Run this on the VM for current connection, sync, and drive details:

```bash
workstation-info
workstation-sync-info
workstation-drive-info
```

## Notes

- Treat disposable workstation VM disks as replaceable.
- Keep active code, git repos, and Docker build contexts under `/workspace`.
- Keep large human-browsable files under `/drive`.
- Do not run databases, package installs, or Docker build contexts directly on `/drive`.
- Host firewall configuration is intentionally left to the provider firewall/security group and Tailscale ACLs. The bootstrap does not install or manage UFW.

## Development and validation

Run the repository validation script before changing bootstrap logic:

```bash
workstation/scripts/verify-source.sh
```

The script runs `bash -n`, config metadata drift checks, lightweight Bash smoke tests, `shellcheck`, `shfmt -d`, `actionlint`, source-tree systemd verification, and `cloud-init schema` for `workstation/cloud-init.example.yml` when the tools are available.

Use strict mode locally to fail instead of skipping missing tools:

```bash
WORKSTATION_STRICT_VALIDATION=1 workstation/scripts/verify-source.sh
```
