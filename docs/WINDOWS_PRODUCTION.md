# Windows Server production with PostgreSQL

This deployment runs AppControl and PostgreSQL as native Windows services. It
does not use Docker Desktop and it uses the PostgreSQL backend rather than the
standalone SQLite backend.

Use the [standalone installer](WINDOWS_DEPLOYMENT.md) for a quick customer
evaluation. Use this page when the Windows installation must retain production
data in PostgreSQL.

## Choose the database location

| Mode | Command option | Use when |
|---|---|---|
| Install PostgreSQL locally | `-PostgresMode Install` | A self-contained single-server installation is acceptable |
| Existing PostgreSQL | `-PostgresMode Existing` | The organization operates a shared, managed or highly available database |

For a critical production service, an externally managed PostgreSQL instance
is preferable: AppControl and its database then do not share the same failure
domain.

## Local PostgreSQL: automated installation

Open Windows PowerShell as Administrator:

```powershell
New-Item -ItemType Directory -Force C:\AppControl-Install | Out-Null
Set-Location C:\AppControl-Install

Invoke-WebRequest `
  -Uri "https://github.com/xcomponent/appcontrol-release/releases/latest/download/appcontrol-windows-server.ps1" `
  -OutFile appcontrol-windows-server.ps1

.\appcontrol-windows-server.ps1 install `
  -PostgresMode Install `
  -AdminEmail "admin@my-company.example"
```

The script:

1. downloads the pinned PostgreSQL 16 installer from EDB;
2. verifies its SHA-256 checksum;
3. installs PostgreSQL server and command-line tools as a Windows service;
4. creates a dedicated `appcontrol` role and database;
5. downloads the PostgreSQL AppControl backend and web interface;
6. installs the backend as an automatic Windows service;
7. verifies the application health endpoint.

Generated credentials are stored in
`C:\ProgramData\AppControl\secrets\installation-secrets.txt`. Its ACL grants
access only to `SYSTEM` and local administrators. Move those credentials into
the organization password vault, then protect or remove the bootstrap file
according to company policy.

Open [http://localhost:3000](http://localhost:3000).

The administrator, database role and PostgreSQL superuser passwords can be
provided explicitly:

```powershell
.\appcontrol-windows-server.ps1 install `
  -PostgresMode Install `
  -AdminEmail "admin@my-company.example" `
  -AdminPassword "APP_PASSWORD" `
  -DatabasePassword "DATABASE_ROLE_PASSWORD" `
  -PostgresSuperuserPassword "POSTGRES_SUPERUSER_PASSWORD" `
  -BackendPort 3000 `
  -PostgresPort 5432
```

If a password is omitted, the script generates a strong random value. See
[all Windows/PostgreSQL installer options](POWERSHELL_COMMANDS.md#windowspostgresql-installer-options),
including custom directories, internal release mirrors and PostgreSQL
installer pinning.

## Create sites, users and teams

The production script exposes the same administration commands as the
standalone script:

```powershell
.\appcontrol-windows-server.ps1 add-site "Paris" 4443
.\appcontrol-windows-server.ps1 create-user "alice@company.example" "Alice Martin"
.\appcontrol-windows-server.ps1 create-team "Production"
.\appcontrol-windows-server.ps1 add-member "Production" "alice@company.example"
.\appcontrol-windows-server.ps1 list-users
```

See the canonical [PowerShell command reference](POWERSHELL_COMMANDS.md) for
sites, hosting groups, permissions, maps and the component catalog.

## Existing PostgreSQL

The database and role must already exist. Include `sslmode=require` when the
database endpoint supports TLS:

```powershell
.\appcontrol-windows-server.ps1 install `
  -PostgresMode Existing `
  -DatabaseUrl "postgresql://appcontrol:PASSWORD@postgres.internal:5432/appcontrol?sslmode=require" `
  -AdminEmail "admin@my-company.example"
```

The connection string is stored in the private environment block of the
`AppControlBackend` Windows service, not as a machine-wide environment
variable. Local administrators can still read it; use a dedicated,
least-privileged PostgreSQL role.

The existing PostgreSQL service must permit the role to connect to the
selected database and create/alter the application schema through migrations.
The installer does not create or modify the remote PostgreSQL server itself.

## Status and removal

```powershell
.\appcontrol-windows-server.ps1 status
.\appcontrol-windows-server.ps1 uninstall
```

Uninstall removes the AppControl Windows service but deliberately preserves
PostgreSQL and all data.

## Installer pinning and internal mirrors

The script pins a tested PostgreSQL maintenance release and checksum. An
organization can mirror the installer internally:

```powershell
.\appcontrol-windows-server.ps1 install `
  -PostgresMode Install `
  -PostgresInstallerUrl "https://packages.internal/postgresql-16-windows-x64.exe" `
  -PostgresInstallerSha256 "EXPECTED_SHA256"
```

Never disable checksum verification.

## Before production

- put port 3000 behind the company IIS or reverse proxy with HTTPS;
- do not expose PostgreSQL port 5432 outside the required network scope;
- store generated secrets in the password vault;
- configure PostgreSQL backups and test a restore;
- review [hardening](HARDENING.md), [backup and restore](BACKUP_RESTORE.md) and
  [upgrade](UPGRADE.md).
