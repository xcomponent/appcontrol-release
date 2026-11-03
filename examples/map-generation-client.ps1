# Compatible with Windows PowerShell 5.1 and PowerShell 7.
# Dot-source this file, then call Get-AppControlGenerationContract.
# No model call and no AppControl import are performed by this helper.

function Get-AppControlGenerationContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Uri] $BaseUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ApiKey,

        [Parameter(Mandatory = $true)]
        [hashtable] $Cache,

        [ValidateSet('standard', 'mock-linux', 'mock-windows')]
        [string] $Profile = 'standard',

        [switch] $IncludeCatalog,

        [string[]] $CatalogTypes = @()
    )

    if (-not $BaseUrl.IsAbsoluteUri -or $BaseUrl.UserInfo -or $BaseUrl.Query -or $BaseUrl.Fragment) {
        throw 'BaseUrl doit etre une URL absolue sans identifiants, parametres ni fragment.'
    }
    if ($BaseUrl.Scheme -ne 'https') {
        throw 'Utiliser une URL HTTPS AppControl avec un certificat approuve par le poste.'
    }

    $query = 'profile=' + [Uri]::EscapeDataString($Profile)
    if ($IncludeCatalog -or $CatalogTypes.Count -gt 0) {
        $query += '&include_catalog=true'
        if ($CatalogTypes.Count -gt 0) {
            $types = @($CatalogTypes | Sort-Object -Unique)
            if (@($types | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_.Contains(',') }).Count -gt 0) {
                throw 'Chaque CatalogTypes doit etre une cle non vide, sans virgule.'
            }
            $query += '&catalog_types=' + [Uri]::EscapeDataString(($types -join ','))
        }
    }
    $url = $BaseUrl.AbsoluteUri.TrimEnd('/') + '/api/v1/map-generation/contract?' + $query

    # Isolate the cache by server, options and identity. The credential itself is
    # never saved in the cache or returned. The caller owns this in-memory cache.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($url + "`n" + $ApiKey)
        $cacheKey = [Convert]::ToBase64String($sha.ComputeHash($bytes))
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
    finally {
        $sha.Dispose()
    }

    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $client = New-Object System.Net.Http.HttpClient ($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $request = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get, $url)
    $response = $null
    try {
        $request.Headers.Add('Authorization', 'ApiKey ' + $ApiKey)
        if ($Cache.ContainsKey($cacheKey)) {
            $request.Headers.TryAddWithoutValidation('If-None-Match', $Cache[$cacheKey].ETag) | Out-Null
        }
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        if ([int] $response.StatusCode -eq 304) {
            if (-not $Cache.ContainsKey($cacheKey)) {
                throw 'Le serveur a retourne 304 sans contrat conserve dans le cache.'
            }
            return ($Cache[$cacheKey].Content | ConvertFrom-Json)
        }
        if ([int] $response.StatusCode -ne 200) {
            throw ('Recuperation du contrat refusee : HTTP ' + [int] $response.StatusCode + '. Verifier URL, version AppControl et droits de la cle.')
        }
        if ($null -eq $response.Headers.ETag) {
            throw 'Le serveur ne fournit pas de ETag pour le contrat.'
        }
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $contract = $content | ConvertFrom-Json
        if (-not $contract.contract_version -or -not $contract.system_prompt -or -not $contract.user_message_template) {
            throw 'Reponse incomplete : contrat de generation AppControl attendu.'
        }
        $Cache[$cacheKey] = @{
            ETag = $response.Headers.ETag.ToString()
            Content = $content
        }
        return $contract
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose()
        $client.Dispose()
    }
}
