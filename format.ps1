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
$installation=''
try {
    $msbuild=Get-RedMonitorMSBuild
    $installation=([IO.FileInfo]$msbuild).Directory.Parent.Parent.Parent.FullName
} catch [System.Management.Automation.RuntimeException] {
    # Standalone LLVM on PATH remains supported when Visual Studio is absent.
    Write-Verbose "Visual Studio formatter discovery unavailable: $($_.Exception.Message)"
}
$command=Get-Command clang-format.exe -ErrorAction SilentlyContinue|Select-Object -First 1
$formatter=Find-RedMonitorClangFormat -VisualStudioInstallation $installation -PathFormatter $(if($command){$command.Source}else{''})
$version=& $formatter --version
if($LASTEXITCODE -ne 0){throw "Could not identify formatter: $formatter"}
Write-Host "Formatter: $version ($formatter)"
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
