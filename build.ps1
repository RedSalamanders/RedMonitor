<#
.SYNOPSIS
Builds the standalone RedMonitor viewer, satellites and console tests.
.DESCRIPTION
Discovers Visual Studio and restores exact dependencies unless SkipRestore is set. Writes only .build;
does not clean source or terminate independently launched processes. Publishes a build receipt on success.
.PARAMETER Platform
x64 or ARM64 target architecture.
.PARAMETER Configuration
Debug, Release or ASan Debug.
.PARAMETER SkipRestore
Use already restored exact dependencies.
.PARAMETER ViewerTests
Auto enables viewer test hooks in Debug/ASan and disables them in Release. Explicit true/false is receipt-bound.
.PARAMETER ProductionOnly
Build only the production viewer and satellites; excludes console test targets.
.PARAMETER BuildNumber
Explicit frozen batch version component. Zero preserves the local default version.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string] $Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string] $Configuration='Debug', [switch] $SkipRestore,
      [ValidateSet('Auto','true','false')][string]$ViewerTests='Auto',
      [switch]$ProductionOnly, [ValidateRange(0,65535)][int]$BuildNumber=0)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($env:CI_NATIVE_BUILDS_DISABLED -eq 'true') { throw 'Native builds are forbidden in compiler-free PR checks.' }
if($ProductionOnly -and ($Configuration -ne 'Release' -or $ViewerTests -eq 'true')){
    throw 'ProductionOnly requires a test-disabled Release viewer.'
}
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
$lease=Enter-RedMonitorOperation "artifact-$Platform-$Configuration"
try {
$output=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ".build/$Platform/$Configuration")
Assert-RedMonitorOutputNotRunning $output
if (-not $SkipRestore) { & (Join-Path $PSScriptRoot 'restore.ps1') -Platform $Platform }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$receipt=Join-Path $output 'build-receipt.json'
if(Test-Path -LiteralPath $receipt){Remove-Item -LiteralPath $receipt}
$identity=Get-RedMonitorSourceIdentity
$msbuild=Get-RedMonitorMSBuild
$started=[DateTime]::UtcNow
$viewerTestsEnabled=if($ViewerTests -eq 'Auto'){$Configuration -ne 'Release'}else{$ViewerTests -eq 'true'}
& $msbuild (Join-Path $PSScriptRoot 'RedMonitor.proj') /nologo /m:4 /v:minimal "/p:Platform=$Platform" "/p:Configuration=$Configuration" "/p:RedMonitorViewerTestsEnabled=$($viewerTestsEnabled.ToString().ToLowerInvariant())" "/p:RedMonitorProductionOnly=$($ProductionOnly.IsPresent.ToString().ToLowerInvariant())" "/p:RedMonitorBuildNumber=$BuildNumber" "/flp:LogFile=$output/build.log;Verbosity=normal"
if($LASTEXITCODE -ne 0){throw "RedMonitor build failed: $output/build.log"}
$version=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $output 'RedMonitor.exe'))
if($version.ProductName -cne 'RedMonitor' -or $version.FileBuildPart -ne $BuildNumber -or
   (($version.SpecialBuild -ceq 'RedSalamander.TestSurface=ENABLE_TESTS') -ne $viewerTestsEnabled)){
    throw 'Viewer version/test-surface metadata does not match the requested build mode.'
}
if($identity -cne (Get-RedMonitorSourceIdentity)){throw 'Source changed during build; no receipt published.'}
$artifacts=@(Get-ChildItem -LiteralPath $output -Recurse -File | Where-Object {
    ($_.DirectoryName -ieq $output -and $_.Extension -in '.exe','.dll','.pdb' -and $_.Name -ne 'yyjson.dll') -or
    $_.Name -eq 'SettingsStore.schema.json' -or $_.FullName -match '[\\/](Lang|Themes)[\\/]'
} | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($output,$_.FullName);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
[ordered]@{schemaVersion=1;passed=$true;sourceIdentity=$identity;platform=$Platform;configuration=$Configuration;viewerTestsEnabled=$viewerTestsEnabled;
  buildNumber=$BuildNumber;productionOnly=[bool]$ProductionOnly;
  dxui=Get-Content (Join-Path $PSScriptRoot 'Dependencies/DxUi.lock.json') -Raw|ConvertFrom-Json;
  toolchainSha256=(Get-FileHash -LiteralPath $msbuild).Hash;artifacts=$artifacts;
  startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');runtimeExecuted=$false}|
  ConvertTo-Json -Depth 8|Set-Content -LiteralPath $receipt -Encoding utf8
Write-Host "Built RedMonitor: $output/RedMonitor.exe"
} finally {$lease.ReleaseMutex();$lease.Dispose()}
