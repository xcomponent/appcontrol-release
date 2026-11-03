#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot '../examples/map-publication-client.ps1')
function Assert-Client([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message} }

# Reject unsafe destinations before creating an HTTP request. No server is used.
foreach($url in @('http://example.test','https://user:secret@example.test','https://example.test/?q=1','https://example.test/#part')) {
    $denied=$false
    try {$null=Get-AppControlPublicationContext -BaseUrl $url -ApiKey 'test-key'} catch {$denied=$true}
    Assert-Client $denied ('Unsafe base URL accepted: '+$url)
}
$script:calls=New-Object System.Collections.ArrayList
function Invoke-AppControlPublicationApi {
    param($BaseUrl,$ApiKey,$Method,$Path,$Body)
    [void]$script:calls.Add([pscustomobject]@{method=$Method;path=$Path;body=$Body})
    if($Method -eq 'GET'){return [pscustomobject]@{sites=@()}}
    if($Path -eq '/map-generation/prepare') {
        if($Body.name -eq 'protocol'){return [pscustomobject]@{issues=@()}}
        if($Body.name -eq 'missing-issues'){return [pscustomobject]@{ready=$true}}
        return [pscustomobject]@{ready=($Body.name -ne 'unresolved');issues=@([pscustomobject]@{code='test-diagnostic'});map=[pscustomobject]@{changed='server-prepared'}}
    }
    if($Body.name -eq 'failed-import'){throw 'HTTP 409: no retry'}
    return [pscustomobject]@{application_id=$Body.name}
}
$options=@{BaseUrl='https://example.test';ApiKey='test-key'}
$null=Get-AppControlPublicationContext @options -SiteCode 'A&B' -HostingName 'DC Paris'
Assert-Client ($script:calls[0].path -ceq '/map-generation/context?profile=standard&site_code=A%26B&hosting_name=DC%20Paris') 'Context defaults to standard and escapes selectors'
$script:calls.Clear()
$results=@(Import-AppControlMaps @options -Requests @(@{name='ready'}))
Assert-Client ($results.Count -eq 1 -and $results[0].success -and $results[0].ready -and -not $results[0].imported -and $script:calls.Count -eq 1) 'Default operation must prepare only'
$script:calls.Clear()
$original=@{name='ready';map=@{source='original'}}
$results=@(Import-AppControlMaps @options -Requests @(@{name='unresolved'},$original,@{name='failed-import'},@{name='protocol'},@{name='missing-issues'},@{name='last'}) -Importer)
Assert-Client ($results.Count -eq 6) 'Batch lost results after a failure'
Assert-Client (-not $results[0].success -and -not $results[0].imported -and $results[0].issues[0].code -ceq 'test-diagnostic') 'Unresolved preparation must return issues and block import'
Assert-Client ($results[1].success -and $results[1].imported -and $results[1].result.application_id -ceq 'ready') 'Ready candidate was not imported'
Assert-Client (-not $results[2].success -and -not $results[2].imported) 'Failed publication was reported as successful'
Assert-Client (-not $results[3].success -and -not $results[3].imported) 'Invalid prepare response must never publish'
Assert-Client (-not $results[4].success -and -not $results[4].imported) 'Missing prepare diagnostics must never fail after an import'
Assert-Client ($results[5].success -and $results[5].index -eq 6) 'Later batch entries must still run'
$imports=@($script:calls|Where-Object path -eq '/map-generation/import')
Assert-Client ($imports.Count -eq 3) 'Unresolved candidates imported or publication retried'
Assert-Client ([object]::ReferenceEquals($imports[0].body,$original)) 'Import must receive the original request, not the prepared projection'
Write-Output 'PASS: publication helper HTTPS guards, escaped context, prepare-only, ready gate, original envelope, batch isolation and no retry.'
