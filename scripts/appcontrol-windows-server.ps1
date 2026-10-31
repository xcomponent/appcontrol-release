#Requires -Version 5.1
<#
.SYNOPSIS
    Install AppControl with PostgreSQL as native Windows services.

.EXAMPLE
    .\appcontrol-windows-server.ps1 install -PostgresMode Install

.EXAMPLE
    .\appcontrol-windows-server.ps1 install -PostgresMode Existing `
      -DatabaseUrl "postgresql://appcontrol:password@db.internal:5432/appcontrol?sslmode=require"
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet(
        "install", "status", "uninstall",
        "add-site", "add-hosting", "assign-site-hosting",
        "import-example", "import-map",
        "create-user", "create-team", "add-member", "grant-access",
        "list-users", "list-teams",
        "init-catalog", "list-catalog", "get-catalog",
        "create-catalog", "delete-catalog", "import-catalog"
    )]
    [string]$Command = "install",
    [Parameter(Position = 1)]
    [string]$Arg1,
    [Parameter(Position = 2)]
    [string]$Arg2,

    [ValidateSet("Install", "Existing")]
    [string]$PostgresMode = "Existing",

    [string]$DatabaseUrl,
    [string]$DatabasePassword,
    [string]$PostgresSuperuserPassword,
    [int]$PostgresPort = 5432,
    [string]$AdminEmail = "admin@localhost",
    [string]$AdminPassword,
    [int]$BackendPort = 3000,

    [string]$InstallDir = "$env:ProgramFiles\AppControl",
    [string]$DataDir = "$env:ProgramData\AppControl",
    [string]$AdminScriptPath,
    [string]$ReleasesBase = "https://github.com/xcomponent/appcontrol-release/releases/latest/download",

    # PostgreSQL 16.14 installer certified by EDB. Override both values when
    # using an internal mirror or updating the pinned maintenance release.
    [string]$PostgresInstallerUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.14-1-windows-x64.exe",
    [string]$PostgresInstallerSha256 = "D389834DF279A9B7CE4B4A030B6545FD0BEFB05385FF66932AC37454AD9B9312"
)

$ErrorActionPreference = "Stop"
$script:BackendService = "AppControlBackend"
$script:PostgresService = "postgresql-x64-16"
$script:SecretsDir = Join-Path $DataDir "secrets"
$script:FrontendDir = Join-Path $DataDir "frontend"
$script:LogsDir = Join-Path $DataDir "logs"
$script:BackendExe = Join-Path $InstallDir "appcontrol-backend.exe"
if (-not $AdminScriptPath) {
    $AdminScriptPath = Join-Path $DataDir "admin\appcontrol.ps1"
}

function Assert-WindowsAdministrator {
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        throw "This operation is available on Windows Server only."
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run Windows PowerShell as Administrator."
    }
}

function Protect-InstallerManagedPath {
    param(
        [string]$Path,
        [switch]$Directory
    )
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $systemSid = New-Object Security.Principal.SecurityIdentifier(
        [Security.Principal.WellKnownSidType]::LocalSystemSid, $null
    )
    $administratorsSid = New-Object Security.Principal.SecurityIdentifier(
        [Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null
    )

    if ($Directory) {
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $inheritance = [Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    } else {
        $acl = New-Object Security.AccessControl.FileSecurity
        $inheritance = [Security.AccessControl.InheritanceFlags]::None
    }
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($currentSid)
    foreach ($sid in @($systemSid, $administratorsSid, $currentSid)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        )
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Write-Step {
    param([string]$Message)
    Write-Host "[AppControl] $Message" -ForegroundColor Cyan
}

function New-RandomSecret {
    param([int]$Bytes = 32)
    $buffer = New-Object byte[] $Bytes
    $generator = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    try {
        $generator.GetBytes($buffer)
        # Keep command-line and connection-string handling predictable while
        # satisfying common Windows password-complexity policies.
        return ([Convert]::ToBase64String($buffer).Replace("/", "A").Replace("+", "B").TrimEnd("=") + "!aA1")
    } finally {
        $generator.Dispose()
    }
}

function Assert-SafeIdentifier {
    param([string]$Value, [string]$Name)
    if ($Value -notmatch '^[a-zA-Z][a-zA-Z0-9_]{0,62}$') {
        throw "$Name must contain only letters, digits and underscores and start with a letter."
    }
}

function Invoke-CheckedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [hashtable]$Environment
    )
    $previous = @{}
    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            $previous[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
            [Environment]::SetEnvironmentVariable($key, $Environment[$key], "Process")
        }
    }
    try {
        $stdoutPath = Join-Path $env:TEMP ("appcontrol-process-{0}.out" -f [Guid]::NewGuid())
        $stderrPath = Join-Path $env:TEMP ("appcontrol-process-{0}.err" -f [Guid]::NewGuid())
        $escapedArguments = @($ArgumentList | ForEach-Object {
            $value = [string]$_
            if ($value -match '[\s"]') {
                '"' + $value.Replace('"', '\"') + '"'
            } else {
                $value
            }
        })
        $process = Start-Process -FilePath $FilePath `
            -ArgumentList ($escapedArguments -join " ") -Wait -PassThru `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if ($process.ExitCode -ne 0) {
            if (Test-Path $stdoutPath) { Get-Content $stdoutPath | Write-Host }
            if (Test-Path $stderrPath) {
                Get-Content $stderrPath | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
            throw "$FilePath exited with code $($process.ExitCode)."
        }
    } finally {
        Remove-Item $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        if ($Environment) {
            foreach ($key in $Environment.Keys) {
                [Environment]::SetEnvironmentVariable($key, $previous[$key], "Process")
            }
        }
    }
}

function Get-VerifiedReleaseAsset {
    param([string]$Name, [string]$Destination)
    $base = $ReleasesBase.TrimEnd("/")
    $checksums = Join-Path $env:TEMP "appcontrol-checksums-sha256.txt"
    Invoke-WebRequest -Uri "$base/checksums-sha256.txt" `
        -OutFile $checksums -UseBasicParsing

    Invoke-WebRequest -Uri "$base/$Name" -OutFile $Destination -UseBasicParsing
    $line = Get-Content $checksums |
        Where-Object { $_ -match ("^[0-9a-fA-F]{64}\s+\*?" + [Regex]::Escape($Name) + "$") } |
        Select-Object -First 1
    if (-not $line) {
        Remove-Item $Destination -Force -ErrorAction SilentlyContinue
        throw "No SHA-256 entry was published for $Name."
    }
    $expected = ($line -split '\s+')[0].ToUpperInvariant()
    $actual = (Get-FileHash -Path $Destination -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        Remove-Item $Destination -Force -ErrorAction SilentlyContinue
        throw "Checksum mismatch for $Name. Expected $expected, got $actual."
    }
}

function Save-InstallationSecrets {
    param(
        [string]$DatabaseSecret,
        [string]$AdministratorSecret,
        [string]$PostgresSecret
    )
    New-Item -ItemType Directory -Force $script:SecretsDir | Out-Null
    $path = Join-Path $script:SecretsDir "installation-secrets.txt"
    $databaseLines = if ($PostgresMode -eq "Install") {
        @"
AppControl database user: appcontrol
AppControl database password: $DatabaseSecret
PostgreSQL superuser: postgres
PostgreSQL superuser password: $PostgresSecret
"@
    } else {
        "Database: external - credentials are contained in the supplied service connection string"
    }
    @"
Generated during AppControl installation.
Protect this file with the server backup and password-management policy.

AppControl administrator: $AdminEmail
AppControl administrator password: $AdministratorSecret
$databaseLines
"@ | Set-Content -Path $path -Encoding UTF8

    Protect-InstallerManagedPath -Path $path
    Write-Step "Initial secrets saved with restricted ACLs: $path"
}

function Install-LocalPostgres {
    param([string]$SuperPassword)

    $existing = Get-Service -Name $script:PostgresService -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Step "PostgreSQL service already exists; keeping it."
        if ($existing.Status -ne "Running") { Start-Service $script:PostgresService }
        return
    }

    $installer = Join-Path $env:TEMP "postgresql-16-windows-x64.exe"
    Write-Step "Downloading the pinned PostgreSQL installer from EDB..."
    Invoke-WebRequest -Uri $PostgresInstallerUrl -OutFile $installer -UseBasicParsing

    $actualHash = (Get-FileHash -Path $installer -Algorithm SHA256).Hash
    if ($actualHash -ne $PostgresInstallerSha256.ToUpperInvariant()) {
        Remove-Item $installer -Force
        throw "PostgreSQL installer checksum mismatch. Expected $PostgresInstallerSha256, got $actualHash."
    }

    $postgresRoot = Join-Path $env:ProgramFiles "PostgreSQL\16"
    $postgresData = Join-Path $DataDir "postgresql"
    New-Item -ItemType Directory -Force $postgresData | Out-Null

    Write-Step "Installing PostgreSQL 16 as a Windows service..."
    $arguments = @(
        "--mode", "unattended",
        "--unattendedmodeui", "none",
        "--enable-components", "server,commandlinetools",
        "--disable-components", "pgAdmin,stackbuilder",
        "--prefix", $postgresRoot,
        "--datadir", $postgresData,
        "--serverport", [string]$PostgresPort,
        "--servicename", $script:PostgresService,
        "--superpassword", $SuperPassword,
        "--servicepassword", $SuperPassword,
        "--enable_acledit", "1"
    )
    try {
        Invoke-CheckedProcess -FilePath $installer -ArgumentList $arguments
    } finally {
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }

    $service = Get-Service -Name $script:PostgresService -ErrorAction Stop
    if ($service.Status -ne "Running") { Start-Service $script:PostgresService }
}

function Initialize-AppControlDatabase {
    param([string]$SuperPassword, [string]$AppPassword)

    Assert-SafeIdentifier -Value "appcontrol" -Name "Database user"
    $psql = Join-Path $env:ProgramFiles "PostgreSQL\16\bin\psql.exe"
    if (-not (Test-Path $psql)) { throw "psql was not found at $psql." }

    $escapedPassword = $AppPassword.Replace("'", "''")
    $sqlPath = Join-Path $env:TEMP ("appcontrol-database-{0}.sql" -f [Guid]::NewGuid())
    @"
DO `$appcontrol`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'appcontrol') THEN
        CREATE ROLE appcontrol LOGIN PASSWORD '$escapedPassword';
    ELSE
        ALTER ROLE appcontrol WITH LOGIN PASSWORD '$escapedPassword';
    END IF;
END
`$appcontrol`$;

SELECT 'CREATE DATABASE appcontrol OWNER appcontrol'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'appcontrol')\gexec
ALTER DATABASE appcontrol OWNER TO appcontrol;
"@ | Set-Content -Path $sqlPath -Encoding ASCII
    $environment = @{ PGPASSWORD = $SuperPassword }

    Write-Step "Creating the AppControl PostgreSQL role and database..."
    try {
        Invoke-CheckedProcess -FilePath $psql -ArgumentList @(
            "-h", "127.0.0.1", "-p", [string]$PostgresPort,
            "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1",
            "-f", $sqlPath
        ) -Environment $environment
    } finally {
        Remove-Item $sqlPath -Force -ErrorAction SilentlyContinue
    }
}

function Set-ServiceEnvironment {
    param([string[]]$Values)
    $serviceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$script:BackendService"
    New-ItemProperty -Path $serviceKey -Name "Environment" -PropertyType MultiString `
        -Value $Values -Force | Out-Null
}

function Install-AdminCommands {
    $adminDir = Split-Path -Parent $AdminScriptPath
    New-Item -ItemType Directory -Force $adminDir | Out-Null
    Get-VerifiedReleaseAsset -Name "appcontrol.ps1" -Destination $AdminScriptPath

    $configDir = Join-Path $adminDir "config"
    New-Item -ItemType Directory -Force $configDir | Out-Null
    @{
        jwt_secret = "managed-by-windows-service"
        admin_email = $AdminEmail
        admin_password = $script:AdminPassword
        org_name = "AppControl"
        backend_port = [string]$BackendPort
    } | ConvertTo-Json | Set-Content (Join-Path $configDir "settings.json") -Encoding UTF8
    if (-not (Test-Path (Join-Path $configDir "sites.json"))) {
        "[]" | Set-Content (Join-Path $configDir "sites.json") -Encoding UTF8
    }
    Protect-InstallerManagedPath -Path $adminDir -Directory
}

function Install-AppControl {
    Assert-WindowsAdministrator
    New-Item -ItemType Directory -Force $InstallDir, $DataDir, $script:FrontendDir, $script:LogsDir | Out-Null

    if (-not $AdminPassword) { $script:AdminPassword = New-RandomSecret }
    else { $script:AdminPassword = $AdminPassword }

    if ($PostgresMode -eq "Install") {
        if (-not $DatabasePassword) { $script:DatabasePassword = New-RandomSecret }
        else { $script:DatabasePassword = $DatabasePassword }
        if (-not $PostgresSuperuserPassword) { $script:PostgresPassword = New-RandomSecret }
        else { $script:PostgresPassword = $PostgresSuperuserPassword }
        Install-LocalPostgres -SuperPassword $script:PostgresPassword
        Initialize-AppControlDatabase -SuperPassword $script:PostgresPassword `
            -AppPassword $script:DatabasePassword
        $encoded = [Uri]::EscapeDataString($script:DatabasePassword)
        $script:DatabaseUrl = "postgresql://appcontrol:${encoded}@127.0.0.1:$PostgresPort/appcontrol"
    } else {
        if (-not $DatabaseUrl) {
            throw "-DatabaseUrl is required when -PostgresMode Existing is selected."
        }
        $script:DatabaseUrl = $DatabaseUrl
        $script:DatabasePassword = "(external database)"
        $script:PostgresPassword = "(external database - managed by your organization)"
    }

    Write-Step "Downloading the PostgreSQL backend and web interface..."
    Get-VerifiedReleaseAsset -Name "appcontrol-backend-windows-amd64.exe" `
        -Destination $script:BackendExe
    $frontendArchive = Join-Path $env:TEMP "appcontrol-frontend.zip"
    Get-VerifiedReleaseAsset -Name "appcontrol-frontend.zip" `
        -Destination $frontendArchive
    Expand-Archive -Path $frontendArchive -DestinationPath $script:FrontendDir -Force
    Remove-Item $frontendArchive -Force

    $jwtSecret = New-RandomSecret -Bytes 48
    if (Get-Service -Name $script:BackendService -ErrorAction SilentlyContinue) {
        Stop-Service $script:BackendService -Force -ErrorAction SilentlyContinue
        Invoke-CheckedProcess -FilePath $script:BackendExe -ArgumentList @("service", "uninstall")
    }
    Invoke-CheckedProcess -FilePath $script:BackendExe -ArgumentList @("service", "install")

    Set-ServiceEnvironment -Values @(
        "DATABASE_URL=$script:DatabaseUrl",
        "JWT_SECRET=$jwtSecret",
        "PORT=$BackendPort",
        "STATIC_DIR=$script:FrontendDir",
        "APP_ENV=production",
        "LOG_FORMAT=json",
        "RUST_LOG=info",
        "LOCAL_AUTH_ENABLED=true",
        "SEED_ENABLED=true",
        "SEED_ADMIN_EMAIL=$AdminEmail",
        "SEED_ADMIN_PASSWORD=$script:AdminPassword",
        "SEED_ORG_NAME=AppControl",
        "SEED_ORG_SLUG=appcontrol"
    )
    Install-AdminCommands

    if ($PostgresMode -eq "Install") {
        & sc.exe config $script:BackendService depend= $script:PostgresService | Out-Null
    }
    Start-Service $script:BackendService

    Write-Step "Waiting for the backend..."
    $healthy = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        try {
            $response = Invoke-RestMethod "http://127.0.0.1:$BackendPort/health" -TimeoutSec 2
            if ($response.status -eq "ok") { $healthy = $true; break }
        } catch {}
        Start-Sleep -Seconds 1
    }
    if (-not $healthy) {
        throw "AppControl did not become healthy. Check the Windows Application event log."
    }

    Save-InstallationSecrets -DatabaseSecret $script:DatabasePassword `
        -AdministratorSecret $script:AdminPassword -PostgresSecret $script:PostgresPassword
    Write-Host ""
    Write-Host "AppControl is ready: http://localhost:$BackendPort" -ForegroundColor Green
    Write-Host "Administrator: $AdminEmail"
}

function Show-Status {
    Assert-WindowsAdministrator
    Get-Service -Name $script:BackendService, $script:PostgresService `
        -ErrorAction SilentlyContinue |
        Select-Object Name, Status, StartType |
        Format-Table -AutoSize
}

function Uninstall-AppControl {
    Assert-WindowsAdministrator
    if (Get-Service -Name $script:BackendService -ErrorAction SilentlyContinue) {
        Stop-Service $script:BackendService -Force -ErrorAction SilentlyContinue
        Invoke-CheckedProcess -FilePath $script:BackendExe -ArgumentList @("service", "uninstall")
    }
    Write-Step "AppControl service removed. PostgreSQL and all data were preserved."
}

function Invoke-AdminCommand {
    if (-not (Test-Path $AdminScriptPath)) {
        throw "Administration command script not found at $AdminScriptPath. Run install first."
    }
    $arguments = @($Command)
    if ($Arg1) { $arguments += $Arg1 }
    if ($Arg2) { $arguments += $Arg2 }
    & $AdminScriptPath @arguments
    if (-not $?) {
        throw "Administration command '$Command' failed with exit code $LASTEXITCODE."
    }
}

$lifecycleCommands = @("install", "status", "uninstall")
switch ($Command) {
    "install" { Install-AppControl }
    "status" { Show-Status }
    "uninstall" { Uninstall-AppControl }
    default {
        if ($lifecycleCommands -notcontains $Command) { Invoke-AdminCommand }
    }
}
