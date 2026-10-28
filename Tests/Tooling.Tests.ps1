<#
.SYNOPSIS
Runs framework-free output-boundary and shared changelog behavior tests.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$valid=Join-Path $root '.build/tooling-tests'
if((Assert-RedMonitorOutputPath $valid) -ine [IO.Path]::GetFullPath($valid)){throw 'Contained output rejected.'}
foreach($path in @($root,(Split-Path $root -Parent),(Join-Path $root '.build/../../foreign-output'))){
    $rejected=$false
    try{$null=Assert-RedMonitorOutputPath $path}catch{$rejected=$true}
    if(-not $rejected){throw "Escaping output accepted: $path"}
}
$scratch=Assert-RedMonitorOutputPath (Join-Path $valid ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $scratch -Force|Out-Null
& (Join-Path $root 'Tools/Test-ChangelogWorkflow.ps1') -ScratchRoot $scratch
& (Join-Path $PSScriptRoot 'Tooling.Tests.AgentGuidance.ps1')
Write-Host 'PASS: canonical output boundary, changelog and agent-guidance behavior'
