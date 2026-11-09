<#
.SYNOPSIS
Explains or runs affected validation and explicit local Full/PrePush qualification.
.PARAMETER Explain
Print required coverage without executing it.
.PARAMETER Mode
Affected compares cumulative committed and dirty work: owned prose runs independent checks, native/unknown work also tests Debug, and no change evaluates nothing. Full/PrePush retain all local profiles; PrePush also checks CHANGELOG.md against origin/main. No hosted CI pass is inferred.
#>
[CmdletBinding()]
param([switch]$Explain,[ValidateSet('Affected','Full','PrePush')][string]$Mode='Affected')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Invoke-CheckedChangeCommand {
    param([string]$Relative,[hashtable]$Parameters=@{})
    $global:LASTEXITCODE=0
    & (Join-Path $PSScriptRoot $Relative) @Parameters
    $succeeded=$?
    if(-not $succeeded -or $LASTEXITCODE){throw "Validation failed: $Relative (exit $LASTEXITCODE)."}
}
# PrePush must reject an invalid changelog before build or test discovery, including in isolated callers.
if(-not $Explain -and $Mode -eq 'PrePush'){Invoke-CheckedChangeCommand 'Tools/Test-Changelog.ps1' @{Base='origin/main'}}
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
$sourceBefore=if(-not $Explain){Get-RedMonitorSourceIdentity -Root $PSScriptRoot}else{''}
$plan=Get-RedMonitorChangePlan -Root $PSScriptRoot
Write-Host "Affected inputs: $($plan.kind). $($plan.reason)"
foreach($path in $plan.paths){Write-Host "  $path"}
if($Explain){
    Write-Host "Mode $Mode : independent validation; Debug runtime when native/unknown inputs changed."
    if($Mode -ne 'Affected'){Write-Host 'Also x64 Release/ASan runtime and all three ARM64 cross-builds. Native/manual/UI/performance gates remain separate.'}
    return
}
if($Mode -eq 'Affected' -and $plan.kind -ceq 'None'){
    if((Get-RedMonitorSourceIdentity -Root $PSScriptRoot) -cne $sourceBefore){throw 'Inputs changed during planning; run again on the current tree.'}
    Write-Host 'NOTHING_SELECTED; repository NOT_EVALUATED';return
}
# Pending fragments are expected: they are folded on the default branch after merge. CHANGELOG.md may change only by such a fold.
if($Mode -ne 'PrePush'){Invoke-CheckedChangeCommand 'Tools/Test-Changelog.ps1'}
Invoke-CheckedChangeCommand 'validate.ps1'
Invoke-CheckedChangeCommand 'format.ps1' @{Check=$true}
Invoke-CheckedChangeCommand 'Tests/Tooling.Tests.ps1'
if((Get-RedMonitorSourceIdentity -Root $PSScriptRoot) -cne $sourceBefore){throw 'Inputs changed during independent validation; run again on the current tree.'}
if($Mode -eq 'Affected' -and $plan.kind -ceq 'Prose'){Write-Host 'PROSE_CHECKS_PASSED; repository NOT_EVALUATED';return}
$configs=if($Mode -eq 'Affected'){@('Debug')}else{@('Debug','Release','ASan Debug')}
foreach($configuration in $configs){Invoke-CheckedChangeCommand 'test.ps1' @{Configuration=$configuration;IncludeLiveEtw=($Mode -ne 'Affected')}}
if($Mode -ne 'Affected'){
    foreach($configuration in 'Debug','Release','ASan Debug'){Invoke-CheckedChangeCommand 'build.ps1' @{Platform='ARM64';Configuration=$configuration}}
    $package=Invoke-CheckedChangeCommand 'package.ps1' @{PassThru=$true}
    Invoke-CheckedChangeCommand 'Tests/Tooling.Tests.Installation.ps1' @{PackageDirectory=$package.extracted}
}
if($Mode -eq 'Affected'){Write-Host 'SELECTED_DEBUG_PASSED; repository NOT_EVALUATED'}
else{Write-Host 'LOCAL_OBLIGATIONS_PASSED; native ARM64/manual gates remain separate'}
