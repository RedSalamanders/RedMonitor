[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string] $Platform = 'x64')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$pinPath = Join-Path $PSScriptRoot 'Dependencies/DxUi.lock.json'
$pin = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json
if ($pin.repository -cne 'https://github.com/RedSalamanders/DxUi' -or
    $pin.commit -cnotmatch '^[0-9a-f]{40}$' -or $pin.apiRevision -ne 4 -or
    @($pin.targets).Count -ne 1 -or $pin.targets[0] -cne 'DxUi') { throw 'Invalid exact DxUi API-4 lock.' }
$dependencyRoot = Join-Path $PSScriptRoot '.build/dependencies/DxUi'
$source = Join-Path $dependencyRoot "source/$($pin.commit)"
if (-not (Test-Path -LiteralPath $source)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $source) | Out-Null
    & git clone -c core.longpaths=true --filter=blob:none --no-checkout "$($pin.repository).git" $source
    if ($LASTEXITCODE -ne 0) { throw "DxUi clone failed; inspect the incomplete restore at '$source'." }
    & git -C $source checkout --detach $pin.commit
    if ($LASTEXITCODE -ne 0) { throw 'Cannot check out the locked DxUi commit.' }
}
& (Join-Path $source 'Tools/validate_consumer.ps1') -DxUiRoot $source -LockFile $pinPath
if ($LASTEXITCODE -ne 0) { throw 'DxUi source pin validation failed.' }
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $source 'Tools/ConsumerBuild.psm1') -Force
$msbuild = Get-RedMonitorMSBuild
$previousHost = [Environment]::GetEnvironmentVariable('PreferredToolArchitecture', 'Process')
try {
    $env:PreferredToolArchitecture = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
    $identity = Get-DxUiConsumerBuildIdentity -DxUiRoot $source -MSBuildPath $msbuild -Platform $Platform
} finally {
    [Environment]::SetEnvironmentVariable('PreferredToolArchitecture', $previousHost, 'Process')
}
$output = (Join-Path $dependencyRoot $identity.Fingerprint) + '\'
& (Join-Path $source 'vcpkg-install.ps1') -Platform $Platform -OutputRoot $output
if ($LASTEXITCODE -ne 0) { throw 'DxUi dependency restore failed.' }
$properties = [ordered]@{
    DxUiRoot=$source; DxUiConsumerOutputRoot=$output; DxUiConsumerLockFile=$pinPath;
    DxUiConsumerToolset=$identity.Identity.toolset; DxUiConsumerVCToolsVersion=$identity.Identity.vcToolsVersion;
    DxUiConsumerSdkVersion=$identity.Identity.windowsSdkVersion;
    DxUiConsumerPreferredToolArchitecture=$identity.Identity.preferredToolArchitecture
}
$xml = '<Project><PropertyGroup>'
foreach ($entry in $properties.GetEnumerator()) {
    $xml += '<' + $entry.Key + '>' + [Security.SecurityElement]::Escape([string]$entry.Value) + '</' + $entry.Key + '>'
}
$xml += '</PropertyGroup></Project>'
$propsPath=Join-Path $dependencyRoot "DxUi.resolved.$Platform.props"
if (-not (Test-Path -LiteralPath $propsPath) -or [IO.File]::ReadAllText($propsPath) -cne $xml) { [IO.File]::WriteAllText($propsPath,$xml) }
$identityPath=Join-Path $dependencyRoot "DxUi.identity.$Platform.json"
$identityJson=$identity | ConvertTo-Json -Depth 7
if (-not (Test-Path -LiteralPath $identityPath) -or [IO.File]::ReadAllText($identityPath).TrimEnd() -cne $identityJson) {
    [IO.File]::WriteAllText($identityPath,$identityJson)
}
Write-Host "DxUi $($pin.commit), API 4, $Platform restored."
