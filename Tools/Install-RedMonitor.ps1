<#
.SYNOPSIS
Installs a separately packaged production Release RedMonitor into a standard application folder.
.DESCRIPTION
Validates the entire package before staging an atomic directory replacement. Running viewers block replacement
and are never killed. Previous installations are retained as named backups. No app repository is required.
.PARAMETER PackageDirectory
Extracted RedMonitor package containing package-receipt.json. Defaults to this script's directory in the ZIP.
.PARAMETER Scope
CurrentUser uses LocalAppData/Programs/RedMonitor; LocalMachine uses ProgramFiles/RedMonitor and needs write rights.
.PARAMETER TestInstallDirectory
Harness-only destination below this source repository's .build. Never selects a real standard installation.
#>
[CmdletBinding()]
param([string]$PackageDirectory=$PSScriptRoot,[ValidateSet('CurrentUser','LocalMachine')][string]$Scope='CurrentUser',
      [string]$TestInstallDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$package=[IO.Path]::GetFullPath($PackageDirectory).TrimEnd('\')
function Assert-NoReparse([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    if((Test-Path -LiteralPath $full) -and ((Get-Item -LiteralPath $full -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
        throw "Reparse installation path: $full"
    }
    for($directory=[IO.DirectoryInfo]::new((Split-Path $full));$directory;$directory=$directory.Parent){
        if($directory.Exists -and ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Reparse installation ancestor: $full"}
    }
    $full
}
$manifest=Get-Content -LiteralPath (Assert-NoReparse (Join-Path $package 'package-receipt.json')) -Raw|ConvertFrom-Json
if($manifest.schemaVersion -ne 1 -or $manifest.configuration -cne 'Release' -or $manifest.apiRevision -ne 1 -or
   $manifest.commit -cnotmatch '^[0-9a-f]{40}$' -or $manifest.platform -notin 'x64','ARM64'){throw 'Not a supported Release package.'}
if($manifest.platform -eq 'ARM64' -and [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64'){
    throw 'An ARM64 viewer requires an ARM64 Windows installation.'
}
$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$files=@(foreach($entry in $manifest.files){
    $relative=([string]$entry.path).Replace('\','/')
    if(-not $relative -or $relative -match '(^/|:|(^|/)\.\.(/|$))' -or -not $names.Add($relative)){throw 'Unsafe or duplicate package path.'}
    $file=Assert-NoReparse (Join-Path $package $relative)
    if(-not $file.StartsWith($package+'\',[StringComparison]::OrdinalIgnoreCase) -or
       -not(Test-Path -LiteralPath $file -PathType Leaf) -or (Get-FileHash -LiteralPath $file).Hash -ine $entry.sha256){throw "Changed/missing package file: $relative"}
    [pscustomobject]@{source=$file;relative=$relative}
})
$required=@('RedMonitor.exe','SettingsStore.schema.json','LICENSE.txt','DxUi-LICENSE.txt','wil-LICENSE.txt','yyjson-LICENSE.txt','vcruntime140.dll')
$required+=@('cs-CZ','fr-FR','ja-JP','sk-SK'|ForEach-Object {"Lang/RedSalamanderMonitor-$_.dll"})
foreach($name in $required){if(-not $names.Contains($name)){throw "Incomplete package: $name"}}
if(-not @($names|Where-Object {$_ -like 'Themes/*'}).Count){throw 'Missing theme closure.'}
$version=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $package 'RedMonitor.exe'))
if($version.ProductName -cne 'RedMonitor' -or $version.IsDebug -or $version.IsSpecialBuild -or $version.SpecialBuild){
    throw 'The helper must be a production Release RedMonitor image.'
}
if($TestInstallDirectory){
    $testRoot=[IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot) '.build'))+'\'
    $destination=Assert-NoReparse $TestInstallDirectory
    if(-not $destination.StartsWith($testRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Harness installation must stay under source .build.'}
}else{
    $base=if($Scope -eq 'CurrentUser'){Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs'}else{[Environment]::GetFolderPath('ProgramFiles')}
    if(-not $base){throw 'Standard application folder unavailable.'}
    $destination=Assert-NoReparse (Join-Path $base 'RedMonitor')
}
foreach($process in @(Get-Process -Name RedMonitor -ErrorAction SilentlyContinue)){
    if($process.Path -and $process.Path -ieq (Join-Path $destination 'RedMonitor.exe')){throw "Close viewer PID $($process.Id) before updating this installation."}
}
$parent=Split-Path $destination
New-Item -ItemType Directory -Force -Path $parent|Out-Null
$stage=Assert-NoReparse (Join-Path $parent ('.RedMonitor-stage-'+[guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $stage|Out-Null
foreach($file in $files){
    $target=Assert-NoReparse (Join-Path $stage $file.relative)
    New-Item -ItemType Directory -Force -Path (Split-Path $target)|Out-Null
    Copy-Item -LiteralPath $file.source -Destination $target
    if((Get-FileHash -LiteralPath $file.source).Hash -cne (Get-FileHash -LiteralPath $target).Hash){throw 'Staged installation hash mismatch.'}
}
Copy-Item -LiteralPath (Join-Path $package 'package-receipt.json') -Destination $stage
$backup=$null
if(Test-Path -LiteralPath $destination){
    $backup=Assert-NoReparse ($destination+'.previous-'+[guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $destination -Destination $backup
}
try{Move-Item -LiteralPath $stage -Destination $destination}
catch{if($backup -and -not(Test-Path -LiteralPath $destination)){Move-Item -LiteralPath $backup -Destination $destination};throw}
Write-Host "Installed Release RedMonitor: $destination"
if($backup){Write-Host "Previous installation retained: $backup"}
