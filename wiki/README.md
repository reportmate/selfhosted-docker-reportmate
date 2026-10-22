# Self-hosted ReportMate wiki

This repository runs ReportMate on your own infrastructure. It pulls the published dashboard and API images, starts them beside PostgreSQL with Docker Compose, and can bake the same stack into a VM appliance image with Packer. It builds no application code: it owns the deployment files and the part of the database schema the API does not create itself.

## Read first

- [Quick start, configuration and upgrades](../README.md)
- [Compose stack](../docker-compose.yml)
- [Environment template](../.env.example)
- [Database schema](../schema/init.sql)

## Architecture

[`docker-compose.yml`](../docker-compose.yml) defines three services on one bridge network. `postgres` runs `postgres:16-alpine` with a named data volume. `api` runs `ghcr.io/reportmate/reportmate-api` on port 8000 and waits for the database health check. `web` runs `ghcr.io/reportmate/web` on port 3000 and reaches the API over the internal network. `REPORTMATE_TAG` selects the image tag for both application services.

Configuration comes from `.env`, copied from [`.env.example`](../.env.example). Compose refuses to start without `DB_PASSWORD`, `API_INTERNAL_SECRET`, `REPORTMATE_PASSPHRASE` and `NEXTAUTH_SECRET`. `DEMO_MODE` defaults to `true`, which bypasses sign-in; setting it to `false` requires the Entra ID variables described in the README.

The schema has two owners. [`schema/init.sql`](../schema/init.sql) creates `devices`, `events` and one table per collection module, and Postgres runs it only when the data volume is empty. Every statement is idempotent, so an existing database is upgraded by running the file again. The API creates and migrates its own tables with Alembic when it starts, and `init.sql` does not repeat them.

The appliance lives in [`packer/`](../packer/). [`reportmate.pkr.hcl`](../packer/reportmate.pkr.hcl) builds a qcow2 image from an Ubuntu cloud image, and [`setup.sh`](../packer/setup.sh) installs Docker, stages the stack in `/opt/reportmate` and enables a systemd unit. On first boot the unit generates secrets when no `.env` exists and starts the stack.

## Development and verification

Use the [README](../README.md) for setup and upgrade commands. Validate a change to the stack locally with:

```
cp .env.example .env && docker compose config --quiet
```

[CI](../.github/workflows/ci.yml) runs on every pull request, on pushes to `main` and weekly. The `validate` job checks the Compose file, runs `packer validate` on the template and ShellCheck on `setup.sh`. The `schema` job starts the published API image on a new database and on one upgraded from the first released `init.sql`, sends a check-in carrying every module, and fails if any module is not stored. The weekly run catches a new API release that needs a table this repository lacks.

## Documentation ownership

Keep this wiki as the entry point and update the linked pages where the facts belong: commands and configuration in the README, service definitions in the Compose file, and schema notes beside `init.sql`. Application behaviour belongs with the API and dashboard repositories. Examples use fictional data. Deployment inventories, credentials, provider mappings and organization-specific operations belong with their deployment owner.
