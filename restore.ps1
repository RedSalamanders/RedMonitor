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
& (Join-Path $PSScriptRoot 'vcpkg-install.ps1') -Platform $Platform
& (Join-Path $PSScriptRoot 'restore-dxui.ps1') -Platform $Platform
