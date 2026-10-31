# Quickstart

Choose the environment where AppControl will run. The database is determined
by that choice; the two backend binaries are intentionally separate.

| Your need | Recommended deployment | Database | Typical setup time |
|---|---|---|---|
| Evaluate on an internal Windows Server | [Standalone PowerShell](WINDOWS_DEPLOYMENT.md) | Embedded SQLite | A few minutes |
| Run a production service on Windows Server | [Native Windows services](WINDOWS_PRODUCTION.md) | Local or existing PostgreSQL 16 | About 10–20 minutes |
| Evaluate on a Linux server with containers | [Docker Compose](COMPOSE.md) | Included PostgreSQL 16 | About 10 minutes |
| Run on Kubernetes | [Helm](PRODUCTION_DEPLOYMENT.md) | External PostgreSQL 16 | Platform dependent |
| Run on OpenShift | [OpenShift](OPENSHIFT.md) | External/operator PostgreSQL 16 | Platform dependent |

For an isolated OpenShift evaluation with verified internal TLS and a bundled
database, use the [guided evaluation installer](qualification/INSTALLATION-EVALUATION.fr.md).
For bank-approved base images and internal registries, see the
[deployment audit](qualification/AUDIT-BANQUE-2026-10-08.fr.md).

## Fastest path: Windows Server

No Docker and no database installation are required:

```powershell
New-Item -ItemType Directory -Force C:\AppControl | Out-Null
Set-Location C:\AppControl
Invoke-WebRequest `
  -Uri "https://github.com/xcomponent/appcontrol-release/releases/latest/download/appcontrol.ps1" `
  -OutFile appcontrol.ps1
.\appcontrol.ps1 install -Email "admin@my-company.example" -Password "replace-this-password"
.\appcontrol.ps1 start
.\appcontrol.ps1 add-site "Evaluation"
```

Open [http://localhost:3000](http://localhost:3000). Continue with the
[Windows Server guide](WINDOWS_DEPLOYMENT.md) for firewall, automatic startup,
backup and upgrade.

## Important distinctions

- Standalone uses the `appcontrol-backend-sqlite` binary. It is intended for
  evaluation and small single-host installations.
- Compose, Kubernetes and OpenShift use the PostgreSQL backend image.
- Docker Desktop is not supported on Windows Server. If containers are
  required on Windows infrastructure, run the Compose stack in a Linux VM.
- Do not expose a quickstart directly to the Internet. Apply the
[hardening checklist](HARDENING.md) before production use.

## Windows production path

For a durable Windows Server installation, do not start with the SQLite
quickstart. Open Windows PowerShell as Administrator and install the
PostgreSQL variant:

```powershell
New-Item -ItemType Directory -Force C:\AppControl-Install | Out-Null
Set-Location C:\AppControl-Install
Invoke-WebRequest `
  -Uri "https://github.com/xcomponent/appcontrol-release/releases/latest/download/appcontrol-windows-server.ps1" `
  -OutFile appcontrol-windows-server.ps1

.\appcontrol-windows-server.ps1 install `
  -PostgresMode Install `
  -AdminEmail "admin@my-company.example" `
  -AdminPassword "replace-this-password"
```

Continue with [Windows Server production](WINDOWS_PRODUCTION.md). Every
installer parameter is explained in the
[PowerShell command reference](POWERSHELL_COMMANDS.md).

## Banking reconstruction demonstrator

The isolated demo is launched with `./demo-rebuild/scripts/start-codespace-demo.sh`.
It generates a private `.devcontainer/.env`, preserves it across restarts and keeps
Codespaces ports private. Passwords are verified; an existing database requires its
existing administrator password on first migration. Run
`./demo-rebuild/scripts/demo-control.sh verify` before presenting.
See the [demo runbook](../demo-rebuild/RUNBOOK-DEMO.fr.md) for incidents, reset and
the opt-in full-stack recipe. The workload, business figures and external tools are
explicit simulators; backend, gateway, agents and HTTP job calls are real.
