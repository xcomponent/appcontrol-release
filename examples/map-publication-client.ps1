#requires -Version 5.1
# Dot-source in the client's own integration. HTTPS only, no model calls,
# external executable, credential file, import retry or lifecycle operation.

function Invoke-AppControlPublicationApi {
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
        catch { throw 'AppControl non joignable. Verifier son etat avant de retenter une publication : aucun retry automatique.' }
        if (-not $response.IsSuccessStatusCode) {
            # A proxy/server error can echo credentials or source content.
            throw ('AppControl : HTTP ' + [int]$response.StatusCode + ' pour ' + $Path + '. Corriger les droits, placements ou la map ; aucun retry automatique.')
        }
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if ($content) {
            try { return ($content | ConvertFrom-Json) }
            catch { throw 'Reponse JSON AppControl invalide. Verifier le resultat avant toute nouvelle publication.' }
        }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose()
        $client.Dispose()
    }
}

function Get-AppControlPublicationContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Uri]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [ValidateSet('standard','mock-linux','mock-windows')][string]$Profile='standard',
        [string]$SiteCode,
        [string]$HostingName
    )
    $path = '/map-generation/context?profile=' + $Profile
    if ($SiteCode) { $path += '&site_code=' + [Uri]::EscapeDataString($SiteCode) }
    if ($HostingName) { $path += '&hosting_name=' + [Uri]::EscapeDataString($HostingName) }
    Invoke-AppControlPublicationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method GET -Path $path
}

function Import-AppControlMaps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Uri]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        # Each item: contract_version, administrative site_code, placements,
        # optional team_grants, and map as a JSON object. No profile is needed:
        # source commands (real or AI-generated mocks) are preserved by default.
        [Parameter(Mandatory=$true)][object[]]$Requests,
        # Without this switch, prepare only. Standard preserves reviewed commands.
        [switch]$Importer
    )
    $index = 0
    foreach ($item in $Requests) {
        $index++
        try {
            $prepared = Invoke-AppControlPublicationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method POST -Path '/map-generation/prepare' -Body $item
            if ($null -eq $prepared -or -not $prepared.PSObject.Properties['ready'] -or $prepared.ready -isnot [bool]) {
                throw 'Reponse de preparation invalide : indicateur ready absent. Aucune publication effectuee.'
            }
            if (-not $prepared.PSObject.Properties['issues']) {
                throw 'Reponse de preparation invalide : diagnostics issues absents. Aucune publication effectuee.'
            }
            $issues = @($prepared.issues)
            if (-not $prepared.ready) {
                [pscustomobject]@{index=$index;success=$false;ready=$false;imported=$false;issues=$issues;result=$prepared;error='Preparation incomplete : corriger les issues avant publication.'}
                continue
            }
            if ($Importer) {
                # Publish the ORIGINAL envelope. The server repeats placement,
                # permissions and command-policy checks at publication.
                $result = Invoke-AppControlPublicationApi -BaseUrl $BaseUrl -ApiKey $ApiKey -Method POST -Path '/map-generation/import' -Body $item
                [pscustomobject]@{index=$index;success=$true;ready=$true;imported=$true;issues=$issues;result=$result;error=$null}
            } else {
                [pscustomobject]@{index=$index;success=$true;ready=$true;imported=$false;issues=$issues;result=$prepared;error=$null}
            }
        }
        catch {
            [pscustomobject]@{index=$index;success=$false;ready=$false;imported=$false;issues=@();result=$null;error=$_.Exception.Message}
        }
    }
}
