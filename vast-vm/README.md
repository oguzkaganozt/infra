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
RESTIC_REPOSITORY='s3:https://c7a7c7c9096e7a8fc974cec9ded52671.r2.cloudflarestorage.com/vast-workspace/main'
RESTIC_PASSWORD='<strong-restic-password>'
AWS_ACCESS_KEY_ID='<r2-access-key-id>'
AWS_SECRET_ACCESS_KEY='<r2-secret-access-key>'
AWS_DEFAULT_REGION='auto'
```

The Cloudflare account ID is `c7a7c7c9096e7a8fc974cec9ded52671` and the R2 bucket is `vast-workspace`.

Create the R2 access key in Cloudflare Dashboard:

1. Go to R2 Object Storage.
2. Open Account Details, then API Tokens.
3. Create an Account API token or User API token.
4. Use Object Read & Write permissions scoped to the `vast-workspace` bucket.
5. Copy the Access Key ID and Secret Access Key immediately; the secret is only shown once.

Use `vast-env.example` as the template for the Vast.ai environment variables.

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

## Vast.ai Template

A private Vast.ai template has been created for this setup:

```text
Name: vast-vm-workspace
Template ID: 431096
Template hash: 3d74606b0c068fce29a68e417d495cb6
Image: docker.io/vastai/kvm:ubuntu_desktop_22.04-2025-11-21
Disk: 100 GB recommended
Filters: vms_enabled=true direct_port_count>=10 cpu_cores_effective>=16 cpu_ram>=32 gpu_ram>=16
Ports: 22, 8888, 7860, 3000, 4000, 8000, 8080, 5901, 6080, 3389
```

To launch from CLI, search for a VM-capable offer and create an instance with the template hash:

```bash
vastai search offers 'vms_enabled=true verified=true rentable=true rented=false direct_port_count>=10 cpu_cores_effective>=16 cpu_ram>=32 gpu_ram>=16'
vastai create instance <offer-id> --template_hash 3d74606b0c068fce29a68e417d495cb6 --disk 100
```

Exposed ports:

| Port | Use |
|---:|---|
| `22` | SSH |
| `8888` | Jupyter |
| `7860` | Gradio |
| `3000` | Node/dev server |
| `4000` | NoMachine/NX |
| `8000` | FastAPI/dev server |
| `8080` | Web app/dev server |
| `5901` | VNC |
| `6080` | noVNC/browser VNC |
| `3389` | RDP |

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
