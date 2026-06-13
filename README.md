# ReportMate — Self-Hosted

Run ReportMate on your own infrastructure: the Next.js dashboard, the FastAPI ingestion/query API, and PostgreSQL. Two paths are provided:

- **Docker Compose** — pull the published images and run the stack (recommended).
- **Packer appliance** — bake the same stack into a VM image (qcow2/AMI/Azure) for appliance-style deploys.

Images are published to GitHub Container Registry:

- `ghcr.io/reportmate/web`
- `ghcr.io/reportmate/api`

## Quick start (Docker Compose)

You need Docker with the Compose plugin. Copy the environment template:

```
cp .env.example .env
```

Set strong values for `DB_PASSWORD`, `API_INTERNAL_SECRET`, `REPORTMATE_PASSPHRASE`, and `NEXTAUTH_SECRET`. The web and api services must share the same `API_INTERNAL_SECRET`.

Bring the stack up:

```
docker compose up -d
```

Open the dashboard at http://localhost:3000. The API is at http://localhost:8000 (health at `/api/v1/health`). PostgreSQL is seeded from `schema/init.sql` on first start.

## What runs

| Service | Port | Image |
|---|---|---|
| web | 3000 | `ghcr.io/reportmate/web` |
| api | 8000 | `ghcr.io/reportmate/api` |
| postgres | 5432 | `postgres:16-alpine` |

## Authentication

The dashboard ships in **demo mode** (`DEMO_MODE=true`) so it runs without configuring Microsoft Entra ID — sign-in is bypassed and settings are read-only. This is the fastest way to evaluate.

For real sign-in and editable settings, set `DEMO_MODE=false` and provide the Entra ID variables (`AZURE_AD_CLIENT_ID`, `AZURE_AD_CLIENT_SECRET`, `AZURE_AD_TENANT_ID`, `NEXTAUTH_URL`) to the `web` service, and set `SETTINGS_ADMIN_ROLES` to your admin role.

## Pinning a version

`REPORTMATE_TAG` selects the image tag (defaults to `latest`). Pin it in `.env` for reproducible deploys:

```
REPORTMATE_TAG=2026.06.0
```

## Sending data

Point a ReportMate client at your API host and authenticate with the `REPORTMATE_PASSPHRASE` you set.

## Appliance image (Packer)

The `packer/` template builds a self-contained VM image with Docker and the compose stack preinstalled. On first boot it generates secrets (if none were supplied) and starts the stack via a systemd unit.

Build a qcow2 image:

```
packer init packer/reportmate.pkr.hcl && packer build packer/reportmate.pkr.hcl
```

To publish an AMI or Azure image instead, add an `amazon-ebs` or `azure-arm` source to the template — both can reuse `packer/setup.sh` unchanged.

## Schema

`schema/init.sql` is consolidated from the `terraform-azurerm-reportmate` migrations (base modular schema + archive feature + settings). The API also ensures indexes and the settings table idempotently on startup, so an existing database self-updates.

## Resetting

Tear down and remove the database volume to start clean:

```
docker compose down -v
```
