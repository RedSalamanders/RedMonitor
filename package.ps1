<#
.SYNOPSIS
Packages a successful exact-source viewer build and its full runtime/data closure.
.PARAMETER Platform
x64 or ARM64 target.
.PARAMETER Configuration
Release by default; Debug and ASan Debug are diagnostic packages.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Release')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
$lease=Enter-RedMonitorOperation "artifact-$Platform-$Configuration"
try {
$output=Join-Path $PSScriptRoot ".build/$Platform/$Configuration"
$receipt=Get-Content -LiteralPath (Join-Path $output 'build-receipt.json') -Raw|ConvertFrom-Json
if(-not $receipt.passed -or $receipt.sourceIdentity -cne (Get-RedMonitorSourceIdentity)){throw 'Build exact current source before packaging.'}
foreach($artifact in $receipt.artifacts){
    if((Get-FileHash -LiteralPath (Assert-RedMonitorOutputPath (Join-Path $output $artifact.path))).Hash -cne $artifact.sha256){throw "Changed artifact: $($artifact.path)"}
}
$root=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/packages/'+[guid]::NewGuid().ToString('N')))
$stage=Join-Path $root 'RedMonitor'
New-Item -ItemType Directory -Path $stage -Force|Out-Null
foreach($name in 'RedMonitor.exe','SettingsStore.schema.json','Themes','Lang'){
    Copy-Item -LiteralPath (Join-Path $output $name) -Destination $stage -Recurse
}
if($Configuration -eq 'ASan Debug'){
    $runtimes=@(Get-ChildItem -LiteralPath $output -Filter '*asan*.dll')
    if(-not $runtimes){throw 'ASan package is missing its runtime.'}
    $runtimes|Copy-Item -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE.txt') -Destination $stage
$triplet=if($Platform -eq 'x64'){'x64-windows-static-md'}else{'arm64-windows-static-md'}
foreach($dependency in 'wil','yyjson'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ".build/vcpkg_installed/$Platform/$triplet/share/$dependency/copyright") -Destination (Join-Path $stage "$dependency-LICENSE.txt")
}
Copy-Item -LiteralPath (Join-Path $output 'build-receipt.json') -Destination $stage
$packageFiles=@(Get-ChildItem -LiteralPath $stage -Recurse -File|ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($stage,$_.FullName);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
[ordered]@{schemaVersion=1;platform=$Platform;configuration=$Configuration;sourceIdentity=$receipt.sourceIdentity;files=$packageFiles}|
    ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $stage 'package-receipt.json') -Encoding utf8
$zip=Join-Path $root "RedMonitor-$Platform-$($Configuration.Replace(' ','-')).zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip
$extracted=Join-Path $root 'extracted'
Expand-Archive -LiteralPath $zip -DestinationPath $extracted
foreach($file in $packageFiles){
    if((Get-FileHash -LiteralPath (Join-Path $extracted $file.path)).Hash -cne $file.sha256){throw "Package extraction changed $($file.path)"}
}
if((Test-Path -LiteralPath (Join-Path $extracted 'Common.dll')) -or (Test-Path -LiteralPath (Join-Path $extracted 'yyjson.dll'))){
    throw 'Standalone package contains a legacy shared DLL.'
}
Write-Host "Package: $zip"
} finally {$lease.ReleaseMutex();$lease.Dispose()}
