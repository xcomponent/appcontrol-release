# Windows Server: standalone evaluation

This is the recommended way to evaluate AppControl on an internal Windows
Server. It installs the web interface, backend, gateway and agent without
Docker and without a separate database server. Data is stored in an embedded
SQLite database.

!!! info "When to use this mode"

    Use it for a customer evaluation, a proof of concept, a demo, or a small
    single-server installation. For a durable shared production service, use
    [Docker Compose on Linux](COMPOSE.md)
    or [OpenShift](OPENSHIFT.md) with PostgreSQL.

## What you need

- Windows Server 2019 or later, x64
- Windows PowerShell 5.1 or later
- an account allowed to download release assets from GitHub
- administrator rights only if you enable startup at boot or open firewall
  ports

Docker, Rust, Node.js and PostgreSQL are **not** required.

## Install in a few minutes

Open PowerShell in the directory where AppControl should keep its data:

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

Open [http://localhost:3000](http://localhost:3000), then sign in with the
email and password passed to `install`.

From another workstation, use `http://SERVER_NAME:3000` and open the port once
in Windows Firewall:

```powershell
New-NetFirewallRule -DisplayName "AppControl Web" `
  -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```

The gateway listens on port `4443` by default. Open that port only when agents
on other servers must connect to this gateway:

```powershell
New-NetFirewallRule -DisplayName "AppControl Gateway" `
  -Direction Inbound -Protocol TCP -LocalPort 4443 -Action Allow
```

## Start automatically after reboot

Run PowerShell as Administrator:

```powershell
Set-Location C:\AppControl
.\appcontrol.ps1 enable-autostart
```

This creates a Windows scheduled task running under `SYSTEM`. To remove it:

```powershell
.\appcontrol.ps1 disable-autostart
```

## Daily operations

| Action | Command |
|---|---|
| Check all processes | `.\appcontrol.ps1 status` |
| Start | `.\appcontrol.ps1 start` |
| Stop | `.\appcontrol.ps1 stop` |
| Read recent logs | `.\appcontrol.ps1 logs` |
| Add a site | `.\appcontrol.ps1 add-site "Site name" [gateway-port]` |
| Upgrade | `.\appcontrol.ps1 upgrade` |

An upgrade replaces only binaries and the web interface. The database,
configuration and site definitions are preserved.

User, team, site, hosting, map and catalog commands are documented once in the
[PowerShell command reference](POWERSHELL_COMMANDS.md).

## Backup and uninstall

Stop AppControl before copying its data:

```powershell
.\appcontrol.ps1 stop
Copy-Item C:\AppControl\data C:\Backup\AppControl\data -Recurse -Force
Copy-Item C:\AppControl\config C:\Backup\AppControl\config -Recurse -Force
```

To uninstall, stop AppControl, disable automatic startup, then archive or
remove `C:\AppControl`. No system-wide database or container runtime remains.

## Directory layout

```text
C:\AppControl\
  appcontrol.ps1
  bin\          downloaded executables
  config\       configuration and sites (preserved by upgrade)
  data\         SQLite database and agent state (preserved by upgrade)
  frontend\     web interface
  logs\         component logs
```

## Security boundary

The quick install serves HTTP directly. It is suitable on a protected internal
network for evaluation. Do not expose port 3000 to the Internet. For a
production deployment, put it behind the company HTTPS reverse proxy, change
the initial password, restrict firewall access, and follow the
[hardening checklist](HARDENING.md).

## Troubleshooting

```powershell
.\appcontrol.ps1 status
.\appcontrol.ps1 logs
Get-Content .\logs\backend.err.log -Tail 100
```

If PowerShell blocks the script for the current process:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```
