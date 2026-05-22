# workstation

Vendor-agnostic bootstrap for disposable Ubuntu cloud workstations.

The target is any fresh Ubuntu 22.04 or 24.04 VM from any provider. Create the VM however you prefer, pass only Infisical bootstrap credentials, and run one command. The bootstrap handles secrets, networking, GUI access, workspace restore, and backups.

## Stack

| Component | Purpose |
|---|---|
| Infisical | Secrets source of truth |
| Tailscale | Stable private networking and SSH |
| XFCE | Lightweight desktop environment for server images |
| NoMachine | Remote GUI desktop on port `4000` |
| Restic | Encrypted `/workspace` snapshots |
| Cloudflare R2 | S3-compatible object storage backend |
| systemd | Periodic and shutdown backups |

## Bootstrap

Simplest path: create an Infisical service token scoped to `prod:/` with read access, then set only this on the VM or in the provider startup environment:

```bash
export INFISICAL_TOKEN='<infisical-service-token>'
```

Then run:

```bash
curl -fsSL https://raw.githubusercontent.com/oguzkaganozt/infra/main/workstation/bootstrap.sh | sudo -E bash
```

Optional bootstrap variables:

```bash
export INFISICAL_API_URL='https://app.infisical.com'
export INFISICAL_SECRET_PATH='/'
export WORKSTATION_REPO_BRANCH='main'
export WORKSTATION_REPO_DIR='/opt/workstation-infra'
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

If you prefer machine identities, add a Universal Auth machine identity to the project and give it access to read the environment secrets.

Store only these required secrets in Infisical:

```bash
TS_AUTHKEY='<tailscale-auth-key>'
RESTIC_PASSWORD='<restic-encryption-password>'
AWS_ACCESS_KEY_ID='<r2-access-key-id>'
AWS_SECRET_ACCESS_KEY='<r2-secret-access-key>'
```

Everything else has code defaults:

| Setting | Default |
|---|---|
| `WORKSPACE_DIR` | `/workspace` |
| `RESTIC_TAG` | `workspace` |
| `RESTIC_REPOSITORY` | `s3:https://c7a7c7c9096e7a8fc974cec9ded52671.r2.cloudflarestorage.com/vast-workspace/main` |
| `AWS_DEFAULT_REGION` | `auto` |
| `NOMACHINE_USER` | `workstation` |
| `NOMACHINE_PASSWORD` | `password` |
| `NOMACHINE_DEB_URL` | `https://www.nomachine.com/free/linux/64/deb` |
| `INSTALL_DESKTOP` | `1` |
| `DESKTOP_PACKAGES` | `xfce4 xfce4-goodies dbus-x11 x11-xserver-utils` |
| `INSTALL_NOMACHINE` | `1` |
| `INSTALL_SYSTEMD_TIMER` | `1` |
| `INSTALL_UFW` | `1` |
| `TS_ENABLE_SSH` | `1` |

Optional Infisical overrides are fine, but not required. The most useful optional one is `TS_HOSTNAME`, for example `gpu-workstation`.

The provider only sees the Infisical bootstrap token or machine identity credentials. Real workstation secrets are fetched at bootstrap and written root-only to `/etc/workstation.env`.

## Access

Use Tailscale endpoints instead of provider public IPs or random port mappings:

```text
SSH: ssh workstation@<tailscale-hostname-or-ip>
NoMachine: <tailscale-hostname-or-ip>:4000
Jupyter: http://<tailscale-hostname-or-ip>:8888
Gradio: http://<tailscale-hostname-or-ip>:7860
Dev server: http://<tailscale-hostname-or-ip>:3000
FastAPI: http://<tailscale-hostname-or-ip>:8000
Web app: http://<tailscale-hostname-or-ip>:8080
```

Run this on the VM for current connection and backup details:

```bash
workstation-info
```

## Persistence

Only `WORKSPACE_DIR` is backed up and restored. The default is:

```text
/workspace
```

Backups run every 15 minutes after the first boot delay:

```text
OnBootSec=5min
OnUnitActiveSec=15min
```

A shutdown backup service also attempts a final best-effort backup during graceful shutdown.

Manual commands:

```bash
backup-workspace
restore-workspace
systemctl status workspace-backup.timer
```

## Notes

- Treat the VM disk as disposable.
- Keep long-running work under `/workspace`.
- Use different `RESTIC_TAG` values if running multiple active workstations against the same Restic repository.
- `INSTALL_UFW=1` allows SSH and all traffic on `tailscale0`, but keeps NoMachine and dev ports private to Tailscale by default.
