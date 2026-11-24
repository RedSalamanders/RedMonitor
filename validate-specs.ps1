<# .SYNOPSIS Validates specification indexes and local documentation references. #>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'validate.ps1') -SpecsOnly
