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
$command=Get-Command clang-format.exe -ErrorAction SilentlyContinue|Select-Object -First 1
if($command){$formatter=$command.Source}else{
    $msbuild=Get-RedMonitorMSBuild
    $installation=([IO.FileInfo]$msbuild).Directory.Parent.Parent.Parent.FullName
    $formatter=Join-Path $installation 'VC/Tools/Llvm/x64/bin/clang-format.exe'
}
if(-not(Test-Path -LiteralPath $formatter -PathType Leaf)){throw 'Install Visual Studio C++ Clang tools or put clang-format.exe on PATH.'}
$failed=$false
foreach($dir in 'src','support','include','Tests'){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $dir) -Recurse -File|Where-Object Extension -in '.h','.cpp'){
        $arguments=if($Check){@('--dry-run','--Werror',$file.FullName)}else{@('-i',$file.FullName)}
        & $formatter @arguments
        if($LASTEXITCODE -ne 0){$failed=$true}
    }
}
if($failed){throw 'Native formatting check failed.'}
