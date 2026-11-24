<#
.SYNOPSIS
Checks the manifested RedMonitor client commands against the exact published bytes.
#>
[CmdletBinding()]
param([string]$Directory = $PSScriptRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestPath = Join-Path $Directory 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
$expected = @('Update-RedMonitorClient.ps1', 'Verify-RedMonitorClient.ps1')
if ($manifest -isnot [Collections.IDictionary] -or $manifest['schemaVersion'] -cne 1 -or
    $manifest['apiRevision'] -cne 1 -or @($manifest['files']).Count -ne $expected.Count) {
    throw "Invalid RedMonitor client tooling manifest: $manifestPath"
}
foreach ($name in $expected) {
    $entries = @($manifest['files'] | Where-Object { $_.path -ceq $name })
    if ($entries.Count -ne 1 -or $entries[0].sha256 -cnotmatch '^[a-f0-9]{64}$') {
        throw "Invalid RedMonitor tooling entry: $name"
    }
    $file = Get-Item -LiteralPath (Join-Path $Directory $name) -Force
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ine $entries[0].sha256) {
        throw "RedMonitor tooling bytes do not match the manifest: $name"
    }
}
Write-Host "Verified $($expected.Count) RedMonitor client tooling hashes."
