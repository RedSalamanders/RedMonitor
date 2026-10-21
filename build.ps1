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
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string] $Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string] $Configuration='Debug', [switch] $SkipRestore)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
$output=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ".build/$Platform/$Configuration")
Assert-RedMonitorOutputNotRunning $output
if (-not $SkipRestore) { & (Join-Path $PSScriptRoot 'restore.ps1') -Platform $Platform }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$receipt=Join-Path $output 'build-receipt.json'
if(Test-Path -LiteralPath $receipt){Remove-Item -LiteralPath $receipt}
$identity=Get-RedMonitorSourceIdentity
$msbuild=Get-RedMonitorMSBuild
$started=[DateTime]::UtcNow
& $msbuild (Join-Path $PSScriptRoot 'RedMonitor.proj') /nologo /m:4 /v:minimal "/p:Platform=$Platform" "/p:Configuration=$Configuration" "/flp:LogFile=$output/build.log;Verbosity=normal"
if($LASTEXITCODE -ne 0){throw "RedMonitor build failed: $output/build.log"}
if($identity -cne (Get-RedMonitorSourceIdentity)){throw 'Source changed during build; no receipt published.'}
$artifacts=@(Get-ChildItem -LiteralPath $output -Recurse -File | Where-Object Extension -in '.exe','.dll','.pdb' | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($output,$_.FullName);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
[ordered]@{schemaVersion=1;passed=$true;sourceIdentity=$identity;platform=$Platform;configuration=$Configuration;
  dxui=Get-Content (Join-Path $PSScriptRoot 'Dependencies/DxUi.lock.json') -Raw|ConvertFrom-Json;
  toolchainSha256=(Get-FileHash -LiteralPath $msbuild).Hash;artifacts=$artifacts;
  startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');runtimeExecuted=$false}|
  ConvertTo-Json -Depth 8|Set-Content -LiteralPath $receipt -Encoding utf8
Write-Host "Built RedMonitor: $output/RedMonitor.exe"
