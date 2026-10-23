<#
.SYNOPSIS
Checks production installation, replacement and fail-closed package validation in owned .build fixtures.
.PARAMETER PackageDirectory
An extracted, source-bound Release package produced by package.ps1.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$run=Join-Path $root ('.build/installation-tests/'+[guid]::NewGuid().ToString('N'))
$package=Join-Path $run 'package'
New-Item -ItemType Directory -Force -Path $package|Out-Null
Get-ChildItem -LiteralPath $PackageDirectory -Force|Copy-Item -Destination $package -Recurse
$manifestPath=Join-Path $package 'package-receipt.json'
$baseline=[IO.File]::ReadAllText($manifestPath)
$installer=Join-Path $root 'Tools/Install-RedMonitor.ps1'
$rows=[Collections.Generic.List[object]]::new()
function Invoke-Control([bool]$Pass,[string]$Name,[string]$Destination=''){
    if(-not $Destination){$Destination=Join-Path $run ($Name+'/RedMonitor')}
    $passed=$true
    try{& $installer -PackageDirectory $package -TestInstallDirectory $Destination *> (Join-Path $run ($Name+'.log'))}
    catch{$passed=$false;$_|Out-String|Add-Content -LiteralPath (Join-Path $run ($Name+'.log'))}
    if($passed -ne $Pass){throw "Installation control failed: $Name"}
    if(-not $Pass -and (Test-Path -LiteralPath $Destination)){throw "Rejected installation published files: $Name"}
    $rows.Add([ordered]@{name=$Name;passed=$true})
    Write-Host "PASS installation $Name"
}
Invoke-Control $true 'production'
$destination=Join-Path $run 'production/RedMonitor'
[IO.File]::WriteAllText((Join-Path $destination 'previous-version.txt'),'recover me')
Invoke-Control $true 'replace-preserve-backup' -Destination $destination
$backups=@(Get-ChildItem -LiteralPath (Split-Path $destination) -Directory -Filter 'RedMonitor.previous-*')
if($backups.Count -ne 1 -or [IO.File]::ReadAllText((Join-Path $backups[0].FullName 'previous-version.txt')) -cne 'recover me'){
    throw 'Previous installation was not recoverable.'
}
foreach($field in 'configuration','apiRevision','platform'){
    $manifest=$baseline|ConvertFrom-Json
    $manifest.$field=if($field -eq 'apiRevision'){99}else{'invalid'}
    $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath
    Invoke-Control $false ('foreign-'+$field)
}
foreach($missing in 'vcruntime140.dll','Lang/RedSalamanderMonitor-ja-JP.dll','LICENSE.txt'){
    $manifest=$baseline|ConvertFrom-Json
    $manifest.files=@($manifest.files|Where-Object {([string]$_.path).Replace('\','/') -cne $missing})
    $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath
    Invoke-Control $false ('missing-'+[IO.Path]::GetFileName($missing))
}
foreach($unsafe in '../escape.dll','C:/outside.dll','/absolute.dll','REDMONITOR.EXE'){
    $manifest=$baseline|ConvertFrom-Json
    $manifest.files+=@([pscustomobject]@{path=$unsafe;sha256=('0'*64)})
    $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath
    Invoke-Control $false ('unsafe-'+$rows.Count)
}
[IO.File]::WriteAllText($manifestPath,$baseline)
$binary=Join-Path $package 'RedMonitor.exe'
$bytes=[IO.File]::ReadAllBytes($binary)
[IO.File]::AppendAllText($binary,'tampered')
Invoke-Control $false 'tampered'
[IO.File]::WriteAllBytes($binary,$bytes)
$junctionTarget=Join-Path $run 'junction-target'
New-Item -ItemType Directory -Force -Path $junctionTarget|Out-Null
$junction=Join-Path $run 'junction'
New-Item -ItemType Junction -Path $junction -Target $junctionTarget|Out-Null
Invoke-Control $false 'reparse' -Destination (Join-Path $junction 'RedMonitor')
[ordered]@{passed=$true;packageReceiptSha256=(Get-FileHash (Join-Path $PackageDirectory 'package-receipt.json')).Hash;
    scope='owned installation fixtures; no standard location or desktop mutation';cases=$rows.ToArray()}|
    ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $run 'receipt.json')
Write-Host "PASS $($rows.Count) installation controls: $run"
