# PowerShell command reference

The standalone SQLite deployment and the native Windows/PostgreSQL deployment
provide the same administration commands. Only the script name changes:

```powershell
# Standalone SQLite
.\appcontrol.ps1 COMMAND [ARGUMENTS]

# Windows Server with PostgreSQL
.\appcontrol-windows-server.ps1 COMMAND [ARGUMENTS]
```

Run commands from an account authorized to administer AppControl. Installation,
service and firewall operations additionally require an elevated PowerShell.

## Installation lifecycle

| Command | Standalone SQLite | Windows/PostgreSQL |
|---|---:|---:|
| `install` | Downloads and configures the standalone package | Installs the PostgreSQL production package |
| `start` | Starts local processes | Use `Start-Service AppControlBackend` |
| `stop` | Stops local processes | Use `Stop-Service AppControlBackend` |
| `status` | Shows local processes | Shows AppControl and PostgreSQL services |
| `upgrade` | Replaces binaries/UI and preserves data | Planned; follow [upgrade procedures](UPGRADE.md) meanwhile |
| `uninstall` | Remove the standalone directory after stopping | Removes the AppControl service and preserves PostgreSQL/data |

## Standalone installer options

Complete syntax:

```powershell
.\appcontrol.ps1 install `
  -Email "admin@company.example" `
  -Password "replace-this-password" `
  -BackendPort 3000 `
  -ReleasesBase "https://github.com/xcomponent/appcontrol-release/releases/latest/download"
```

| Option | Default | Description |
|---|---|---|
| `-Email <address>` | `admin@localhost` | Initial local administrator email |
| `-Password <password>` | `admin` | Initial administrator password; always set an explicit value |
| `-BackendPort <port>` | `3000` | HTTP port exposed by the standalone backend |
| `-ReleasesBase <URL>` | Latest customer release | Base URL containing binaries, frontend archive and checksums |

`-ReleasesBase` is useful for an authenticated internal mirror or an air-gapped
HTTP repository. It must contain the platform-specific SQLite backend,
gateway, agent, `appcontrol-frontend.zip` and `checksums-sha256.txt`.

## Windows/PostgreSQL installer options

Open Windows PowerShell as Administrator. Choose exactly one database mode.

### Install PostgreSQL locally

```powershell
.\appcontrol-windows-server.ps1 install `
  -PostgresMode Install `
  -AdminEmail "admin@company.example" `
  -AdminPassword "replace-this-password"
```

### Use an existing PostgreSQL service

```powershell
.\appcontrol-windows-server.ps1 install `
  -PostgresMode Existing `
  -DatabaseUrl "postgresql://appcontrol:PASSWORD@db.company.example:5432/appcontrol?sslmode=require" `
  -AdminEmail "admin@company.example" `
  -AdminPassword "replace-this-password"
```

| Option | Default | Required when | Description |
|---|---|---|---|
| `-PostgresMode Install\|Existing` | `Existing` | Always choose explicitly | Installs PostgreSQL locally or connects to an existing database |
| `-DatabaseUrl <URL>` | None | `PostgresMode Existing` | PostgreSQL connection URL used by the backend service |
| `-DatabasePassword <password>` | Generated | Optional with `Install` | Password for the locally created `appcontrol` database role |
| `-PostgresSuperuserPassword <password>` | Generated | Optional with `Install` | Password assigned to the local PostgreSQL `postgres` account |
| `-PostgresPort <port>` | `5432` | No | Local PostgreSQL listening port |
| `-AdminEmail <address>` | `admin@localhost` | No | Initial AppControl administrator email |
| `-AdminPassword <password>` | Generated | No | Initial AppControl administrator password |
| `-BackendPort <port>` | `3000` | No | AppControl HTTP listening port |
| `-InstallDir <path>` | `C:\Program Files\AppControl` | No | Backend executable installation directory |
| `-DataDir <path>` | `C:\ProgramData\AppControl` | No | Frontend, administration files, logs and PostgreSQL data root |
| `-AdminScriptPath <path>` | `<DataDir>\admin\appcontrol.ps1` | No | Installed administration command script |
| `-ReleasesBase <URL>` | Latest customer release | No | Base URL containing backend, frontend, admin script and checksums |
| `-PostgresInstallerUrl <URL>` | Pinned EDB PostgreSQL 16 installer | No | Approved installer or internal mirror URL |
| `-PostgresInstallerSha256 <hash>` | Pinned tested hash | With an overridden installer URL | Expected SHA-256; verification cannot be disabled |

When passwords are generated, the installer writes them to
`C:\ProgramData\AppControl\secrets\installation-secrets.txt` (or the selected
`DataDir`) with restricted Windows ACLs. Transfer them to the organization
password vault after installation.

The service connection string is readable by local Windows administrators.
Use a dedicated least-privileged PostgreSQL role and prefer
`sslmode=require` for a remote database.

## Standalone-only lifecycle commands

| Command | Purpose |
|---|---|
| `enable-autostart` | Creates the scheduled task that starts the standalone package at boot |
| `disable-autostart` | Removes that scheduled task |
| `logs` | Displays recent standalone component logs |
| `help` | Prints the command summary |

## Sites and hosting

```powershell
.\SCRIPT.ps1 add-site "Paris" 4443
.\SCRIPT.ps1 add-hosting "France" "French production hosting"
.\SCRIPT.ps1 assign-site-hosting "Paris" "France"
```

| Command | Purpose |
|---|---|
| `add-site <name> [gateway-port]` | Creates a site and its gateway/agent enrollment material |
| `add-hosting <name> [description]` | Creates a hosting group |
| `assign-site-hosting <site> <hosting>` | Associates a site with a hosting group |

In standalone mode, `add-site` also starts the locally packaged gateway and
agent when AppControl is running. In Windows/PostgreSQL production mode it
creates the control-plane objects and enrollment material; install the gateway
and remote agents using [Agent installation](AGENT_INSTALLATION.md).

## Users, teams and permissions

```powershell
.\SCRIPT.ps1 create-user "alice@company.example" "Alice Martin"
.\SCRIPT.ps1 create-team "Production" "Production operators"
.\SCRIPT.ps1 add-member "Production" "alice@company.example"
.\SCRIPT.ps1 grant-access "Core Banking" "Production"
.\SCRIPT.ps1 list-users
.\SCRIPT.ps1 list-teams
```

| Command | Purpose |
|---|---|
| `create-user <email> [display-name]` | Creates a local AppControl user |
| `create-team <name> [description]` | Creates a team |
| `add-member <team> <user-email>` | Adds an existing user to a team |
| `grant-access <application> <team-or-email>` | Grants operate permission on an application |
| `list-users` | Lists users |
| `list-teams` | Lists teams |

For enterprise authentication, create or synchronize identities through the
configured OIDC/SAML provider and review [permissions](PERMISSIONS.md).

## Application maps and examples

```powershell
.\SCRIPT.ps1 import-example
.\SCRIPT.ps1 import-example metrics-demo-windows "Paris"
.\SCRIPT.ps1 import-map C:\maps\core-banking.json "Paris"
.\SCRIPT.ps1 import-map https://packages.internal/maps/application.json "Paris"
```

| Command | Purpose |
|---|---|
| `import-example` | Lists packaged examples |
| `import-example <name> [site]` | Imports a packaged example |
| `import-map <path-or-url> [site]` | Imports an application map |

Review remote JSON before importing it. Prefer an authenticated internal
repository and a versioned immutable URL.

## Component catalog

```powershell
.\SCRIPT.ps1 init-catalog
.\SCRIPT.ps1 list-catalog
.\SCRIPT.ps1 get-catalog windows-service
.\SCRIPT.ps1 create-catalog C:\catalog\custom-type.json
.\SCRIPT.ps1 import-catalog C:\catalog\company-catalog.json
.\SCRIPT.ps1 delete-catalog custom-type
```

| Command | Purpose |
|---|---|
| `init-catalog` | Seeds built-in component types |
| `list-catalog` | Lists catalog entries |
| `get-catalog <type-key>` | Prints one entry as JSON |
| `create-catalog <file.json>` | Creates one custom entry |
| `import-catalog <file.json>` | Imports multiple entries from an `entries` array |
| `delete-catalog <type-key>` | Deletes a custom entry |

## Script substitutions in examples

`SCRIPT.ps1` in the examples above means:

```powershell
# Standalone
$script = ".\appcontrol.ps1"

# Native Windows/PostgreSQL
$script = ".\appcontrol-windows-server.ps1"

& $script list-users
```

Use the actual script name when copying a command directly.
