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
$output=Join-Path $PSScriptRoot ".build/$Platform/$Configuration"
$receipt=Get-Content -LiteralPath (Join-Path $output 'build-receipt.json') -Raw|ConvertFrom-Json
if(-not $receipt.passed -or $receipt.sourceIdentity -cne (Get-RedMonitorSourceIdentity)){throw 'Build exact current source before packaging.'}
foreach($artifact in $receipt.artifacts){
    if((Get-FileHash -LiteralPath (Assert-RedMonitorOutputPath (Join-Path $output $artifact.path))).Hash -cne $artifact.sha256){throw "Changed artifact: $($artifact.path)"}
}
$root=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/packages/'+[guid]::NewGuid().ToString('N')))
$stage=Join-Path $root 'RedMonitor'
New-Item -ItemType Directory -Path $stage -Force|Out-Null
foreach($name in 'RedMonitor.exe','yyjson.dll','SettingsStore.schema.json','Themes','fr-FR','ja-JP','cs-CZ','sk-SK'){
    Copy-Item -LiteralPath (Join-Path $output $name) -Destination $stage -Recurse
}
if($Configuration -eq 'ASan Debug'){
    $runtimes=@(Get-ChildItem -LiteralPath $output -Filter '*asan*.dll')
    if(-not $runtimes){throw 'ASan package is missing its runtime.'}
    $runtimes|Copy-Item -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE.txt') -Destination $stage
$triplet=if($Platform -eq 'x64'){'x64-windows'}else{'arm64-windows'}
foreach($dependency in 'wil','yyjson'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ".build/vcpkg_installed/$Platform/$triplet/share/$dependency/copyright") -Destination (Join-Path $stage "$dependency-LICENSE.txt")
}
Copy-Item -LiteralPath (Join-Path $output 'build-receipt.json') -Destination $stage
$zip=Join-Path $root "RedMonitor-$Platform-$($Configuration.Replace(' ','-')).zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip
Write-Host "Package: $zip"
