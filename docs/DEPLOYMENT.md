# Install AppControl: choose a deployment mode

AppControl has two backend variants. Choose the deployment first; do not mix
the SQLite standalone binary with the PostgreSQL container images.

!!! tip "Most common choices"

    For a customer demonstration on Windows, choose **Standalone PowerShell**.
    For an internal production service on Windows Server, choose **Native
    Windows services with PostgreSQL**. Docker Compose is a Linux deployment,
    not a Windows Server deployment.

| Mode | Database | Host | Best for | Installer or package | Guide |
|---|---|---|---|---|---|
| Standalone PowerShell | Embedded SQLite | Windows Server | Evaluation, demonstration, isolated small installation | `appcontrol.ps1` | [Install standalone](WINDOWS_DEPLOYMENT.md) |
| Native Windows services | Local or existing PostgreSQL 16 | Windows Server | Durable internal or customer production service | `appcontrol-windows-server.ps1` | [Install Windows production](WINDOWS_PRODUCTION.md) |
| Docker Compose | Included PostgreSQL 16 | Linux + Docker Engine | Pilot or single-host Linux service | `appcontrol-compose.tar.gz` | [Install Compose](COMPOSE.md) |
| Kubernetes with Helm | External PostgreSQL 16 | Kubernetes | Production platform | Helm chart `appcontrol-*.tgz` | [Install with Helm](PRODUCTION_DEPLOYMENT.md) |
| OpenShift with Helm | External/operator PostgreSQL 16 | OpenShift | Production with restricted SCC | Same Helm chart + OpenShift values | [Install on OpenShift](OPENSHIFT.md) |

## Decision guide

```text
Do you need the fastest customer evaluation?
  Yes -> Windows standalone + SQLite
  No
  |
  +-- Must AppControl run natively on Windows Server?
  |     Yes -> Windows services + PostgreSQL
  |
  +-- Do you already operate Kubernetes or OpenShift?
  |     Kubernetes -> Helm + external PostgreSQL
  |     OpenShift  -> Helm/OpenShift + external PostgreSQL
  |
  +-- Otherwise -> Docker Compose on a Linux server
```

All release downloads come from
[`xcomponent/appcontrol-release`](https://github.com/xcomponent/appcontrol-release/releases/latest).
PowerShell installation parameters and day-two administration commands are
listed in the [PowerShell reference](POWERSHELL_COMMANDS.md).

## Standalone

The standalone package installs the SQLite backend, gateway, frontend and
local services through `appcontrol.ps1`. It does not require Docker or a
separate PostgreSQL server.

Use it when simplicity matters more than horizontal scaling. It is not the
container backend and should not be used as the database mode for Kubernetes
or OpenShift.

This is the only deployment that uses the SQLite backend binary.

## Native Windows production

The production PowerShell installer uses the PostgreSQL backend binary and
registers `AppControlBackend` as an automatic Windows service. It can either
install a pinned PostgreSQL 16 release locally or connect to a database
managed by the organization.

It does not require Docker Desktop. For production data, PostgreSQL provides a
clear backup, restore and lifecycle boundary that the evaluation SQLite mode
does not.

## Docker Compose

Docker Compose runs the PostgreSQL backend and the complete packaged topology:
PostgreSQL, backend, frontend, gateway, TLS initialization and reverse proxy.

Customer releases pull versioned images from `ghcr.io/xcomponent`. Docker
Desktop is not supported on Windows Server; use the standalone mode there, or
run Compose in a Linux VM.

## Kubernetes and OpenShift

Both modes use the same Helm chart and PostgreSQL backend images. OpenShift
adds a Route and security settings compatible with `restricted-v2` and
`restricted-v3`, including arbitrary runtime UIDs.

For production, use an externally managed or operator-managed PostgreSQL
database. The embedded PostgreSQL chart option exists only for ephemeral CI
validation.

## Before production

Whichever mode you choose, review:

- [Hardening checklist](HARDENING.md)
- [Backup and restore](BACKUP_RESTORE.md)
- [Upgrade procedures](UPGRADE.md)
- [Capacity planning](CAPACITY_PLANNING.md)
- [High availability](HIGH_AVAILABILITY.md)
