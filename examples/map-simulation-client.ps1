#requires -Version 5.1
# Dot-source this helper in the client's own integration. No model, Git,
# Python, command execution or credentials on disk. HTTPS trust uses Windows.

function Invoke-AppControlSimulationApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Uri]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [Parameter(Mandatory=$true)][ValidateSet('GET','POST')][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,
        [object]$Body
    )
    if (-not $BaseUrl.IsAbsoluteUri -or $BaseUrl.Scheme -ne 'https' -or
        $BaseUrl.UserInfo -or $BaseUrl.Query -or $BaseUrl.Fragment) {
        throw 'BaseUrl doit etre une URL HTTPS AppControl sans identifiants, parametres ni fragment.'
    }
    if (-not $Path.StartsWith('/map-generation/')) { throw 'Chemin de generation attendu.' }
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $client = New-Object System.Net.Http.HttpClient ($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(120)
    $url = $BaseUrl.AbsoluteUri.TrimEnd('/') + '/api/v1' + $Path
    $request = New-Object System.Net.Http.HttpRequestMessage ((New-Object System.Net.Http.HttpMethod $Method), $url)
    $response = $null
    try {
        $request.Headers.Add('Authorization', 'ApiKey ' + $ApiKey)
        if ($null -ne $Body) {
            $json = ConvertTo-Json -InputObject $Body -Depth 100 -Compress
            $request.Content = New-Object System.Net.Http.StringContent ($json, [Text.Encoding]::UTF8, 'application/json')
        }
        try { $response = $client.SendAsync($request).GetAwaiter().GetResult() }
        catch { throw 'AppControl non joignable. Verifier la connexion puis son etat avant de retenter un import : aucun retry automatique.' }
        if (-not $response.IsSuccessStatusCode) {
            # A server/proxy response can reflect sensitive input; do not echo it.
            throw ('AppControl : HTTP ' + [int]$response.StatusCode + ' pour ' + $Path + '. Corriger les droits, le site ou la map ; aucun retry automatique.')
        }
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if ($content) { return ($content | ConvertFrom-Json) }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose()
        $client.Dispose()
    }
}

function Get-AppControlSimulationContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Uri]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [ValidateSet('mock-linux','mock-windows')][string]$Profile='mock-linux',
        [string]$SiteCode,
        [string]$HostingName
    )
    $path = '/map-generation/context?profile=' + $Profile
    if ($SiteCode) { $path += '&site_code=' + [Uri]::EscapeDataString($SiteCode) }
    if ($HostingName) { $path += '&hosting_name=' + [Uri]::EscapeDataString($HostingName) }
    Invoke-AppControlSimulationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method GET -Path $path
}

function Import-AppControlMockMaps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Uri]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        # Each item is the API envelope: contract_version, profile, site_code
        # (or unambiguous hosting_name), optional dr_site_codes, map JSON object.
        [Parameter(Mandatory=$true)][object[]]$Requests,
        # Without this switch: preparation only, no map is created.
        [switch]$Importer
    )
    $index = 0
    foreach ($item in $Requests) {
        $index++
        try {
            $prepared = Invoke-AppControlSimulationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method POST -Path '/map-generation/mock/prepare' -Body $item
            if ($Importer) {
                # Send the ORIGINAL candidate again: the server rebuilds its
                # safe mock commands and revalidates current default bindings.
                $result = Invoke-AppControlSimulationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method POST -Path '/map-generation/mock/import' -Body $item
                [pscustomobject]@{ index=$index; success=$true; imported=$true; result=$result }
            } else {
                [pscustomobject]@{ index=$index; success=$true; imported=$false; result=$prepared }
            }
        }
        catch {
            # One bad source must not hide the results of all the other maps.
            [pscustomobject]@{ index=$index; success=$false; imported=$false; error=$_.Exception.Message }
        }
    }
}
