<#
.SYNOPSIS
Formats native source with the repository style or verifies it with Check.
.PARAMETER Check
Read-only formatting verification.
#>
[CmdletBinding()]
param([switch]$Check)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Build/Formatting.psm1') -Force
$formatter=Get-RedMonitorClangFormat -Root $PSScriptRoot
$version=@(& $formatter --version)
Write-Host "Using $($version -join ' '): $formatter"
# Parse the unchanged style once, before checking or rewriting any source file.
$assumedFilename=Join-Path $PSScriptRoot 'src/RedMonitor.cpp'
& $formatter --style=file "--assume-filename=$assumedFilename" --dump-config > $null
if($LASTEXITCODE -ne 0){throw "Formatter cannot read the repository style: $version ($formatter). Install compatible Visual Studio C++ Clang tools or LLVM."}
$failed=$false
foreach($dir in 'src','support','include','Tests'){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $dir) -Recurse -File|Where-Object Extension -in '.h','.cpp'){
        $arguments=if($Check){@('--dry-run','--Werror',$file.FullName)}else{@('-i',$file.FullName)}
        & $formatter @arguments
        if($LASTEXITCODE -ne 0){$failed=$true}
    }
}
if($failed){throw 'Native formatting check failed.'}
