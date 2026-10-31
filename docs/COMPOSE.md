# Docker Compose on a Linux server

Docker Compose runs the packaged AppControl topology on one Linux host:
PostgreSQL 16, backend, frontend, gateway, certificate initialization and
HTTPS reverse proxy.

Use this mode for a pilot or a small single-host service when your organization
already operates Docker Engine on Linux. For Windows Server, use the
[standalone installer](WINDOWS_DEPLOYMENT.md) or create a Linux VM for Compose.

## Prerequisites

- a supported Linux distribution
- Docker Engine and Docker Compose v2
- outbound access to `github.com` and `ghcr.io`
- `gh`, `tar` and `openssl`

## Install

Download the self-contained deployment bundle from the customer release:

```bash
mkdir appcontrol && cd appcontrol
gh release download \
  --repo xcomponent/appcontrol-release \
  --pattern appcontrol-compose.tar.gz
tar xzf appcontrol-compose.tar.gz
cd docker
```

Create the required secrets:

```bash
cp .env.example .env
sed -i "s|CHANGE_POSTGRES_PASSWORD|$(openssl rand -hex 24)|" .env
sed -i "s|CHANGE_JWT_SECRET|$(openssl rand -hex 32)|" .env
sed -i "s|CHANGE_ADMIN_PASSWORD|$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)|" .env
chmod 600 .env
```

Record the generated `SEED_ADMIN_PASSWORD` from `.env`, then start:

```bash
docker compose -f docker-compose.release.yaml pull
docker compose -f docker-compose.release.yaml up -d
docker compose -f docker-compose.release.yaml ps
```

Open [https://localhost](https://localhost) on the server and sign in with
`SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD`. The first certificate is
self-signed; replace it with the company certificate before production use.

## Pin a release

Set `APPCONTROL_VERSION` in `.env` to a published version instead of `latest`,
then run:

```bash
docker compose -f docker-compose.release.yaml pull
docker compose -f docker-compose.release.yaml up -d
```

## Operate

```bash
# Status
docker compose -f docker-compose.release.yaml ps

# Logs
docker compose -f docker-compose.release.yaml logs -f --tail=200

# Stop without deleting data
docker compose -f docker-compose.release.yaml down

# Upgrade after changing APPCONTROL_VERSION
docker compose -f docker-compose.release.yaml pull
docker compose -f docker-compose.release.yaml up -d
```

The `pgdata` volume contains the database. Never use `down -v` unless you
intend to erase the installation. See [Backup and restore](BACKUP_RESTORE.md)
before using this mode for business data.

## Production boundary

Compose is a single-host deployment. It does not provide control-plane high
availability. For a critical or regulated service, prefer
[Kubernetes/Helm](PRODUCTION_DEPLOYMENT.md) or [OpenShift](OPENSHIFT.md) with
managed PostgreSQL, and apply the [hardening checklist](HARDENING.md).
