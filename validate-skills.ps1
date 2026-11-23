<# .SYNOPSIS Checks RedMonitor's agent guidance with the pinned CI engine. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Tools/Test-AgentGuidance.ps1') -Root $PSScriptRoot
