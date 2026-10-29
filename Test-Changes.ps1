<#
.SYNOPSIS
Explains or runs affected validation and explicit local Full/PrePush qualification.
.PARAMETER Explain
Print required coverage without executing it.
.PARAMETER Mode
Affected validates and tests Debug; Full/PrePush run all local profiles, and PrePush also checks CHANGELOG.md against origin/main. No hosted CI pass is inferred.
#>
[CmdletBinding()]
param([switch]$Explain,[ValidateSet('Affected','Full','PrePush')][string]$Mode='Affected')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Explain){
    Write-Host "Mode $Mode : validators, native formatting, x64 Debug model/file/lifetime tests."
    if($Mode -ne 'Affected'){Write-Host 'Also x64 Release/ASan runtime and all three ARM64 cross-builds. Native/manual/UI/performance gates remain separate.'}
    return
}
# Pending fragments are expected: they are folded on the default branch after merge. CHANGELOG.md may change only by such a fold.
if($Mode -eq 'PrePush'){& (Join-Path $PSScriptRoot 'Tools/Test-Changelog.ps1') -Base origin/main}
elseif($Mode -eq 'Full'){& (Join-Path $PSScriptRoot 'Tools/Test-Changelog.ps1')}
& (Join-Path $PSScriptRoot 'validate.ps1')
& (Join-Path $PSScriptRoot 'format.ps1') -Check
& (Join-Path $PSScriptRoot 'Tests/Tooling.Tests.ps1')
$configs=if($Mode -eq 'Affected'){@('Debug')}else{@('Debug','Release','ASan Debug')}
foreach($configuration in $configs){& (Join-Path $PSScriptRoot 'test.ps1') -Configuration $configuration -IncludeLiveEtw:($Mode -ne 'Affected')}
if($Mode -ne 'Affected'){
    foreach($configuration in 'Debug','Release','ASan Debug'){& (Join-Path $PSScriptRoot 'build.ps1') -Platform ARM64 -Configuration $configuration}
    $package=& (Join-Path $PSScriptRoot 'package.ps1') -PassThru
    & (Join-Path $PSScriptRoot 'Tests/Tooling.Tests.Installation.ps1') -PackageDirectory $package.extracted
}
