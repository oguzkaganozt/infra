# vast-vm

Bootstrap and persistence scripts for disposable GPU VMs.

The current setup targets Vast.ai true VM instances:

- Recreate the VM environment from GitHub.
- Restore `/workspace` from a Restic repository on S3-compatible storage.
- Back up `/workspace` periodically with systemd.
- Attempt a final backup during shutdown.

## Layout

```text
scripts/
  vast-onstart.sh        # Main Vast.ai startup entrypoint
  restore-workspace.sh   # Restore latest Restic snapshot
  backup-workspace.sh    # Back up /workspace and prune old snapshots
systemd/
  workspace-backup.service
  workspace-backup.timer
  workspace-backup-shutdown.service
```

## Required Secrets

Pass these as environment variables when provisioning the VM. Do not commit them.

```bash
RESTIC_REPOSITORY='s3:https://<account-id>.r2.cloudflarestorage.com/<bucket>/<prefix>'
RESTIC_PASSWORD='<strong-restic-password>'
AWS_ACCESS_KEY_ID='<r2-access-key-id>'
AWS_SECRET_ACCESS_KEY='<r2-secret-access-key>'
AWS_DEFAULT_REGION='auto'
```

Optional variables:

```bash
WORKSPACE_DIR='/workspace'
RESTIC_TAG='workspace'
PROJECT_REPO_URL='git@github.com:org/project.git'
PROJECT_DIR='/workspace/project'
INSTALL_SYSTEMD_TIMER='1'
```

## Vast.ai Onstart Command

If this repo is public:

```bash
apt-get update && apt-get install -y git ca-certificates && git clone https://github.com/oguzkaganozt/infra.git /opt/infra && bash /opt/infra/vast-vm/scripts/vast-onstart.sh
```

If this repo is private, use a read-only deploy key or fine-grained token to clone it. Prefer a deploy key over embedding a long-lived personal token in the Vast template.

## Manual Commands

After bootstrap, these commands are available on the VM:

```bash
backup-workspace
restore-workspace
systemctl status workspace-backup.timer
```

## Notes

- `/workspace` is the persistent working directory.
- The VM local disk is still temporary and should be treated as disposable.
- Restic snapshots are encrypted and incremental.
- Avoid running multiple VMs against the same live workspace unless each VM uses a different `RESTIC_TAG` or path.
