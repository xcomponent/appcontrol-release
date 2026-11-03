# Exercise the exact templates shipped by GET /map-generation/contract using
# Windows PowerShell 5.1 through cmd.exe, as the Windows agent executes them.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'This test requires Windows cmd.exe.' }
$source = Join-Path $PSScriptRoot '../crates/backend/src/api/map_generation_mocks.json'
$templates = (Get-Content -LiteralPath $source -Raw | ConvertFrom-Json).'mock-windows'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('AppControl mock & space ' + [Guid]::NewGuid().ToString('N'))
$oldLocalAppData = $env:LOCALAPPDATA
$oldMockRoot = $env:APPCONTROL_MOCK_ROOT
try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $sentinel = Join-Path $root 'unrelated.txt'
    [System.IO.File]::WriteAllText($sentinel, 'retain')
    function Invoke-PromptMock([string] $Case, [string] $Member, [string] $Phase, [int] $Expected) {
        $command = $templates.$Phase.Replace('member-key', $Member)
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $env:ComSpec
        $info.Arguments = '/D /S /C ' + $command
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($info)
        try {
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -ne $Expected) {
                throw ('Prompt mock ' + $Case + '/' + $Member + '/' + $Phase + ' failed: exit=' + $process.ExitCode + '; ' + $stderr + $stdout)
            }
        }
        finally { $process.Dispose() }
    }
    foreach ($case in @('fallback absent', 'fallback empty', 'override with spaces')) {
        $caseRoot = Join-Path $root $case
        $env:LOCALAPPDATA = Join-Path $caseRoot 'local app data & space'
        # Never let an inherited override turn a fallback test into an override test.
        Remove-Item Env:APPCONTROL_MOCK_ROOT -ErrorAction SilentlyContinue
        $expectedRoot = Join-Path $env:LOCALAPPDATA 'AppControlMock'
        if ($case -eq 'fallback empty') {
            # Windows PowerShell 5.1 treats assigning an empty environment value
            # as removing it. Both empty and absent must select the fallback.
            $env:APPCONTROL_MOCK_ROOT = ''
        }
        elseif ($case -eq 'override with spaces') {
            $env:APPCONTROL_MOCK_ROOT = Join-Path $caseRoot 'override & space'
            $expectedRoot = $env:APPCONTROL_MOCK_ROOT
        }
        [System.IO.Directory]::CreateDirectory($expectedRoot) | Out-Null
        $caseSentinel = Join-Path $expectedRoot 'unrelated.txt'
        [System.IO.File]::WriteAllText($caseSentinel, 'retain')
        $firstMarker = Join-Path $expectedRoot 'application-key/component-key-one.running'
        $secondMarker = Join-Path $expectedRoot 'application-key/component-key-two.running'
        Invoke-PromptMock $case 'one' 'check' 2
        Invoke-PromptMock $case 'one' 'stop' 0
        Invoke-PromptMock $case 'one' 'start' 0
        Invoke-PromptMock $case 'one' 'start' 0
        Invoke-PromptMock $case 'one' 'check' 0
        if (-not (Test-Path -LiteralPath $firstMarker -PathType Leaf)) { throw ('Marker not created under expected root: ' + $case) }
        Invoke-PromptMock $case 'two' 'check' 2
        Invoke-PromptMock $case 'two' 'start' 0
        if (-not (Test-Path -LiteralPath $secondMarker -PathType Leaf)) { throw ('Independent member marker missing: ' + $case) }
        Invoke-PromptMock $case 'one' 'stop' 0
        Invoke-PromptMock $case 'one' 'stop' 0
        Invoke-PromptMock $case 'one' 'check' 2
        Invoke-PromptMock $case 'two' 'check' 0
        Invoke-PromptMock $case 'two' 'stop' 0
        Invoke-PromptMock $case 'two' 'check' 2
        if ((Test-Path -LiteralPath $firstMarker) -or (Test-Path -LiteralPath $secondMarker)) { throw ('Stopped markers remain: ' + $case) }
        if ([System.IO.File]::ReadAllText($caseSentinel) -ne 'retain') { throw ('Unrelated file modified: ' + $case) }
        if ($case -eq 'override with spaces' -and (Test-Path -LiteralPath $env:LOCALAPPDATA)) { throw 'Override unexpectedly wrote into LOCALAPPDATA.' }
        Write-Output ('PASS: prompt templates ' + $case + ', expected root, independent members, idempotent lifecycle, unrelated file retained.')
    }
    if ([System.IO.File]::ReadAllText($sentinel) -ne 'retain') { throw 'Unrelated file modified.' }
    $env:LOCALAPPDATA = $root
    # The materializer uses these exact server-owned templates with a hashed
    # namespace/component/member key, independently of the illustrative contract.
    $materializerSource = Join-Path $PSScriptRoot '../crates/backend/src/core/mock_map_commands.json'
    $materializerTemplates = (Get-Content -LiteralPath $materializerSource -Raw | ConvertFrom-Json).'mock-windows'
    $env:APPCONTROL_MOCK_ROOT = Join-Path $root 'isolated simulation & state'
    function Invoke-MaterializedMock([string] $Member, [string] $Phase, [int] $Expected) {
        $command = $materializerTemplates.$Phase.Replace('__APPCONTROL_MOCK_KEY__', ($Member * 64))
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $env:ComSpec
        $info.Arguments = '/D /S /C ' + $command
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($info)
        try {
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -ne $Expected) {
                throw ('Materialized mock ' + $Member + '/' + $Phase + ' failed: exit=' + $process.ExitCode + '; ' + $stderr + $stdout)
            }
            if (-not [string]::IsNullOrWhiteSpace($stdout)) { return ($stdout | ConvertFrom-Json) }
        }
        finally { $process.Dispose() }
    }
    $initial = Invoke-MaterializedMock 'a' 'check' 2
    if ($initial.availability_simulated -ne 0) { throw 'Absent marker must be stopped.' }
    Invoke-MaterializedMock 'a' 'stop' 0
    Invoke-MaterializedMock 'a' 'start' 0
    Invoke-MaterializedMock 'a' 'start' 0
    $first = Invoke-MaterializedMock 'a' 'check' 0
    if (-not $first.simulation -or $first.requests_simulated_total -ne 7 -or $first.restarts_simulated_total -ne 0) { throw 'Invalid initial simulated metrics.' }
    if (-not $first.synthetic -or $first.source_label -cne 'AppControl file simulation') { throw 'Native simulation provenance banner is missing.' }
    $second = Invoke-MaterializedMock 'a' 'check' 0
    if ($second.requests_simulated_total -ne 14) { throw 'Running requests did not advance.' }
    $other = Invoke-MaterializedMock 'b' 'check' 2
    if ($other.requests_simulated_total -ne 0) { throw 'Members share state.' }
    Invoke-MaterializedMock 'b' 'start' 0
    Invoke-MaterializedMock 'a' 'stop' 0
    Invoke-MaterializedMock 'a' 'stop' 0
    $stopped = Invoke-MaterializedMock 'a' 'check' 2
    if ($stopped.requests_simulated_total -ne 14 -or $stopped.availability_simulated -ne 0) { throw 'Stopped metrics are incoherent.' }
    $other = Invoke-MaterializedMock 'b' 'check' 0
    if ($other.availability_simulated -ne 1) { throw 'Stopping one member affected another.' }
    Invoke-MaterializedMock 'a' 'start' 0
    $restarted = Invoke-MaterializedMock 'a' 'check' 0
    if ($restarted.restarts_simulated_total -ne 1) { throw 'Restart counter did not advance.' }
    if ([System.IO.File]::ReadAllText($sentinel) -ne 'retain') { throw 'Unrelated file modified.' }
    . (Join-Path $PSScriptRoot '../examples/map-generation-client.ps1')
    Write-Output 'PASS: exact Windows mock templates, lifecycle, idempotency, dynamic simulated metrics, independent members, paths with spaces, unrelated file retained; client helper loads in PowerShell 5.1.'
}
finally {
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:APPCONTROL_MOCK_ROOT = $oldMockRoot
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
