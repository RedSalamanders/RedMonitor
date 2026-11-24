<#
.SYNOPSIS
Verifies the published client commands and the SDK refresh contract using local fixtures.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$sdk = Join-Path $root 'Tools/ClientSdk'
$checkManifest = Join-Path $sdk 'Test-ToolingManifest.ps1'
$update = Join-Path $sdk 'Update-RedMonitorClient.ps1'
$verify = Join-Path $sdk 'Verify-RedMonitorClient.ps1'
$fixture = Assert-RedMonitorOutputPath (Join-Path $root ('.build/client-tooling-tests/' + [guid]::NewGuid().ToString('N')))
$bundle = Join-Path $fixture 'bundle'
[void][IO.Directory]::CreateDirectory($bundle)
foreach ($name in 'manifest.json','Update-RedMonitorClient.ps1','Verify-RedMonitorClient.ps1') {
    Copy-Item -LiteralPath (Join-Path $sdk $name) -Destination (Join-Path $bundle $name)
}
& $checkManifest -Directory $bundle

$copy = Join-Path $bundle 'Verify-RedMonitorClient.ps1'
[IO.File]::AppendAllText($copy, '# altered')
$rejected = $false
try { & $checkManifest -Directory $bundle }
catch {
    if ($_.Exception.Message -notlike '*bytes do not match the manifest: Verify-RedMonitorClient.ps1*') { throw }
    $rejected = $true
}
if (-not $rejected) { throw 'The manifest admitted an altered command.' }

$consumer = Join-Path $fixture 'consumer'
$clientFixtureCommit = '1' * 40
$pinPath = Join-Path $consumer 'Dependencies/RedMonitor.lock.json'
$clientFixtureFiles = @{
    'include/RedMonitor/Client.h' = 'inline constexpr int kApiRevision = 1;'
    'LICENSE.txt' = 'Fixture notice'
}
# Supply only the two expected immutable GitHub contents responses.
function gh {
    param([string]$Method,[string]$Request)
    if ($Method -cne 'api' -or $Request -cnotmatch '^repos/RedSalamanders/RedMonitor/contents/(?<path>[^?]+)\?ref=(?<ref>[a-f0-9]{40})$' -or
        $Matches['ref'] -cne $clientFixtureCommit -or -not $clientFixtureFiles.ContainsKey($Matches['path'])) {
        throw 'Unexpected client restore request.'
    }
    $path = $Matches['path']
    $global:LASTEXITCODE = 0
    [ordered]@{type='file';encoding='base64';path=$path;content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($clientFixtureFiles[$path]))} |
        ConvertTo-Json -Compress
}

& $update -Commit $clientFixtureCommit -RepositoryRoot $consumer
& $verify -RepositoryRoot $consumer
$pin = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json -AsHashtable
if ($pin['commit'] -cne $clientFixtureCommit -or $pin.Contains('tooling')) { throw 'Legacy client refresh changed the lock shape.' }
$manifest = Get-Content -LiteralPath (Join-Path $sdk 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
$pin['tooling'] = [ordered]@{schemaVersion=1;commit=('2' * 40);files=$manifest['files']}
[IO.File]::WriteAllText($pinPath, ($pin | ConvertTo-Json -Depth 8))
$expectedTooling = $pin['tooling'] | ConvertTo-Json -Depth 8 -Compress
$clientFixtureCommit = '3' * 40
& $update -Commit $clientFixtureCommit -RepositoryRoot $consumer
& $verify -RepositoryRoot $consumer
if ($IsWindows) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    & $windowsPowerShell -NoProfile -NonInteractive -File $verify -RepositoryRoot $consumer
    if ($LASTEXITCODE -ne 0) { throw 'The client verifier failed in Windows PowerShell 5.1.' }
}
$updated = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json -AsHashtable
if ($updated['commit'] -cne $clientFixtureCommit -or ($updated['tooling'] | ConvertTo-Json -Depth 8 -Compress) -cne $expectedTooling) {
    throw 'Client refresh changed the reviewed tooling pin.'
}
Write-Host "PASS client tooling byte integrity, legacy refresh and tooling-pin preservation. Fixture: $fixture"
