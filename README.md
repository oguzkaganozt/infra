# infra

Shared infrastructure code and operational scripts.

## Modules

| Directory | Purpose |
|---|---|
| `workstation/` | Vendor-agnostic Ubuntu cloud workstation bootstrap |

The workstation bootstrap targets fresh Ubuntu 22.04/24.04 VMs from any provider.
It uses Infisical for secrets, Tailscale for private networking, NoMachine for GUI access,
and Restic with Cloudflare R2 for `/workspace` persistence.
