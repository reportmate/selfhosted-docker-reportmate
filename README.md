# ReportMate — Self-Hosted

Run ReportMate on your own infrastructure: the Next.js dashboard, the FastAPI ingestion/query API, and PostgreSQL. Two paths are provided:

- **Docker Compose** — pull the published images and run the stack (recommended).
- **Packer appliance** — bake the same stack into a VM image (qcow2/AMI/Azure) for appliance-style deploys.

Images are published to GitHub Container Registry:

- `ghcr.io/reportmate/web`
- `ghcr.io/reportmate/reportmate-api`

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

Open the dashboard at http://localhost:3000. The API is at http://localhost:8000 (health at `/api/v1/health`). PostgreSQL is created from `schema/init.sql` on first start, and the API brings it up to date when it starts (see [Schema](#schema)).

## What runs

| Service | Port | Image |
|---|---|---|
| web | 3000 | `ghcr.io/reportmate/web` |
| api | 8000 | `ghcr.io/reportmate/reportmate-api` |
| postgres | 5432 | `postgres:16-alpine` |

## Authentication

The dashboard ships in **demo mode** so it runs without configuring Microsoft Entra ID — sign-in is bypassed and settings are read-only. This is the fastest way to evaluate.

Demo mode is controlled by `DEMO_MODE` in `.env`, which compose passes to the `web` container. It defaults to `true` when unset. The dashboard reads it when the container starts, so no image rebuild is needed; after changing it, apply it with:

```
docker compose up -d
```

`DEMO_MODE` is honoured by `ghcr.io/reportmate/web` images built after the dashboard started reading it at runtime. An older pinned `REPORTMATE_TAG` ignores it and always requires sign-in.

For real sign-in and editable settings, set `DEMO_MODE=false` and provide the
Entra ID variables (`AZURE_AD_CLIENT_ID`, `AZURE_AD_CLIENT_SECRET`,
`AZURE_AD_TENANT_ID`, `NEXTAUTH_URL`) to the `web` service.

Admin access is not configured by an environment variable. The dashboard
checks for the literal role `admin` in the `roles` claim of the signed-in
user's token. Define an app role with the value `admin` on your Entra app
registration and assign it to the users or groups who should administer the
instance; they must sign out and back in for the new claim to appear. Users
without that role can sign in and read the dashboard, but settings stay
read-only.

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

The database schema has two owners:

- `schema/init.sql` creates the tables the API writes to but does not create itself: `devices`, `events`, and one table per collection module (`system`, `hardware`, `peripherals` and the rest).
- The API owns everything else. At startup it runs its Alembic migrations, which create its own tables (`usage_history`, `api_keys`, `app_settings`, `ingest_failures` and others), add derived columns, and manage indexes. Nothing in `init.sql` repeats them.

CI starts the published API image on `schema/init.sql`, both on a new database and on one upgraded from an earlier version of this file, and sends a check-in carrying every module. It runs weekly as well as on each change, so a new API release that needs a table this file lacks fails here.

## Upgrading an existing database

Postgres runs `schema/init.sql` only when the data volume is empty, so a later change to the file never reaches a database that already exists. Every statement in it is idempotent, so the upgrade is to run it again against the running database. It adds what is missing and leaves your data alone.

Get the current files:

```
git pull
```

Apply the schema to the running database:

```
docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U reportmate -d reportmate < schema/init.sql
```

Pull the images and restart, so the API runs its own migrations:

```
docker compose pull && docker compose up -d
```

Confirm the upgrade by checking that the `platform` column and the `peripherals` table exist:

```
docker compose exec postgres psql -U reportmate -d reportmate -c '\d peripherals' -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'devices' AND column_name = 'platform'"
```

On the Packer appliance the stack lives in `/opt/reportmate`, so run the same commands there with `sudo`, copying the new `schema/init.sql` in first.

Run the upgrade whenever `schema/init.sql` changes. A database created from an earlier version of the file has no `devices.platform` column and no `peripherals` table, so current API images answer every check-in with a server error and store no devices until it is upgraded.

## Resetting

Tear down and remove the database volume to start clean:

```
docker compose down -v
```

## License

This deployment tooling — the Compose files, Packer templates, schema, and scripts in this repo — is MIT licensed (see [LICENSE](LICENSE)), like the ReportMate Terraform modules. The application images it pulls are licensed separately: the server (API and dashboard) under AGPL-3.0, the clients under MIT.
