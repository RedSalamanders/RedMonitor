<#
.SYNOPSIS
Checks formatter selection without executing fixture candidates or rewriting source.
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $root 'Build/Formatting.psm1') -Force
$scratch=Assert-RedMonitorOutputPath (Join-Path $root ('.build/formatting-tests/'+[guid]::NewGuid().ToString('N')))
$installation=Join-Path $scratch 'Visual Studio'
$bundled=Join-Path $installation 'VC/Tools/Llvm/x64/bin/clang-format.exe'
$flat=Join-Path $installation 'VC/Tools/Llvm/bin/clang-format.exe'
$pathFormatter=Join-Path $scratch 'old-path-llvm/clang-format.exe'
$repositoryFormatter=Join-Path $scratch 'pinned/clang-format.exe'
foreach($path in $bundled,$flat,$pathFormatter,$repositoryFormatter){
    New-Item -ItemType Directory -Path (Split-Path $path) -Force|Out-Null
    [IO.File]::WriteAllText($path,'fixture, never execute')
}
$before=@(Get-ChildItem -LiteralPath $scratch -Recurse -File|Sort-Object FullName|Get-FileHash|ForEach-Object Hash) -join ','
if((Find-RedMonitorClangFormat $installation $pathFormatter -RepositoryFormatter $repositoryFormatter) -cne $repositoryFormatter){throw 'Ambient tools shadowed the repository formatter.'}
if((Find-RedMonitorClangFormat $installation $pathFormatter -RepositoryFormatter (Join-Path $scratch 'absent.exe')) -cne $bundled){throw 'Missing repository install prevented supported discovery.'}
if((Find-RedMonitorClangFormat $installation $pathFormatter) -cne $bundled){throw 'PATH shadowed the selected Visual Studio formatter.'}
$missingInstallation=Join-Path $scratch 'missing-vs'
if((Find-RedMonitorClangFormat $missingInstallation $pathFormatter) -cne $pathFormatter){throw 'Standalone PATH fallback was lost.'}
if((Find-RedMonitorClangFormat '' $pathFormatter) -cne $pathFormatter){throw 'Standalone formatter incorrectly required Visual Studio.'}
$failed=$false
try{$null=Find-RedMonitorClangFormat $missingInstallation (Join-Path $scratch 'missing.exe')}catch{$failed=$true}
if(-not $failed){throw 'Missing formatter did not fail closed.'}
$after=@(Get-ChildItem -LiteralPath $scratch -Recurse -File|Sort-Object FullName|Get-FileHash|ForEach-Object Hash) -join ','
if($after -cne $before){throw 'Formatter discovery modified fixture candidates.'}
Remove-Item -LiteralPath $bundled
if((Find-RedMonitorClangFormat $installation $pathFormatter) -cne $flat){throw 'Flat Visual Studio LLVM layout was not supported.'}
Write-Host "PASS 8 formatter selection/read-only controls: $scratch"
