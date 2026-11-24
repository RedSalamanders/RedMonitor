<#
.SYNOPSIS
Restores exact standalone RedMonitor and DxUi dependencies.
.DESCRIPTION
Writes only the repository-owned .build tree; never uses or changes a sibling checkout.
.PARAMETER Platform
x64 or ARM64 target architecture.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
Invoke-RedMonitorDependencyRestore -Platform $Platform
