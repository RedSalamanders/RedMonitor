<#
.SYNOPSIS
Resolves the pinned producer SDK and optionally stages a verified viewer package for a consumer.
.DESCRIPTION
Called only from a clean, full-HEAD-verified managed checkout. Outputs stay below ConsumerRoot/.build.
No sibling source lookup, directory cleanup, automatic launch or independent process termination occurs.
.PARAMETER ConsumerRoot
Absolute application repository path containing Dependencies/RedMonitor.lock.json.
.PARAMETER Platform
x64 or ARM64.
.PARAMETER Configuration
Debug, Release or ASan Debug.
.PARAMETER Viewer
Build and stage the complete optional viewer package beneath the selected output's RedMonitor directory.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConsumerRoot,
      [ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Debug', [switch]$Viewer, [switch]$VerifyOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root=[IO.Path]::GetFullPath($ConsumerRoot)
$boundary=(Join-Path $root '.build')+'\'
function Assert-ConsumerOutput([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    if(-not $full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw "Outside consumer .build: $full"}
    for($current=[IO.DirectoryInfo]::new($full);$current;$current=$current.Parent){
        if($current.Exists -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Reparse consumer output: $full"}
    }
    $full
}
$pin=Get-Content -LiteralPath (Join-Path $root 'Dependencies/RedMonitor.lock.json') -Raw|ConvertFrom-Json
$head=& git -C $source rev-parse HEAD
if($LASTEXITCODE -ne 0 -or $head -cne $pin.commit -or (& git -C $source status --porcelain)){throw 'Unverified or dirty RedMonitor source.'}
if($pin.apiRevision -ne 1 -or $pin.repository -cne 'https://github.com/RedSalamanders/RedMonitor'){throw 'Unsupported RedMonitor API/origin.'}
if(-not $source.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'SDK must come from the consumer managed checkout.'}
$props=Assert-ConsumerOutput (Join-Path $root '.build/RedMonitor.resolved.props')
$escaped=[Security.SecurityElement]::Escape((Join-Path $source 'include'))
$content="<Project><PropertyGroup><RedMonitorInclude>$escaped</RedMonitorInclude><RedMonitorCommit>$head</RedMonitorCommit></PropertyGroup></Project>"
if($VerifyOnly){
    if(-not(Test-Path -LiteralPath $props) -or [IO.File]::ReadAllText($props) -cne $content){throw 'Missing or stale RedMonitor resolved props. Run restore-redmonitor.ps1.'}
    return
}
if(-not(Test-Path -LiteralPath $props) -or [IO.File]::ReadAllText($props) -cne $content){
    $temporary=$props+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temporary,$content)
    [IO.File]::Move($temporary,$props,$true)
}
if(-not $Viewer){Write-Host "RedMonitor SDK: $head (API $($pin.apiRevision))";return}
$destination=Assert-ConsumerOutput (Join-Path $root ".build/$Platform/$Configuration/RedMonitor")
foreach($process in @(Get-Process -Name RedMonitor -ErrorAction SilentlyContinue)){
    if($process.Path -and $process.Path -ieq (Join-Path $destination 'RedMonitor.exe')){throw "Close viewer PID $($process.Id) before staging its output."}
}
& (Join-Path $source 'build.ps1') -Platform $Platform -Configuration $Configuration
$package=& (Join-Path $source 'package.ps1') -Platform $Platform -Configuration $Configuration -PassThru
$receipt=Get-Content -LiteralPath (Join-Path $package.extracted 'package-receipt.json') -Raw|ConvertFrom-Json
foreach($entry in $receipt.files){
    $from=[IO.Path]::GetFullPath((Join-Path $package.extracted $entry.path))
    if(-not $from.StartsWith($package.extracted+'\',[StringComparison]::OrdinalIgnoreCase) -or
       (Get-FileHash -LiteralPath $from).Hash -cne $entry.sha256){throw 'Viewer package integrity failed.'}
    $to=Assert-ConsumerOutput (Join-Path $destination $entry.path)
    New-Item -ItemType Directory -Force -Path (Split-Path $to)|Out-Null
    Copy-Item -LiteralPath $from -Destination $to
}
Copy-Item -LiteralPath (Join-Path $package.extracted 'package-receipt.json') -Destination (Join-Path $destination 'package-receipt.json')
Write-Host "Staged optional viewer: $destination"
