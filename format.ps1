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
$pin=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Build/clang-format.json') -Raw|ConvertFrom-Json
$formatter=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/format/'+$pin.entryPath))
if(-not(Test-Path -LiteralPath $formatter -PathType Leaf)){
    $command=Get-Command clang-format.exe -ErrorAction SilentlyContinue|Select-Object -First 1
    if($command){$formatter=$command.Source}else{
        $msbuild=Get-RedMonitorMSBuild
        $installation=([IO.FileInfo]$msbuild).Directory.Parent.Parent.Parent.FullName
        $formatter=Join-Path $installation 'VC/Tools/Llvm/x64/bin/clang-format.exe'
    }
}
if(-not(Test-Path -LiteralPath $formatter -PathType Leaf)){throw 'Run ./Tools/Install-ClangFormat.ps1 to install the pinned formatter.'}
if((Get-Item -LiteralPath $formatter -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Formatter cannot be a reparse point.'}
$version=@(& $formatter --version)
if($LASTEXITCODE -ne 0 -or ($version -join '') -notmatch ('^clang-format version '+[regex]::Escape($pin.version)+'(?:\s|$)')){
    throw "Formatting requires clang-format $($pin.version). Run ./Tools/Install-ClangFormat.ps1. Found: $($version -join ' ')"
}
Write-Host "Using $($version -join ' '): $formatter"
$failed=$false
foreach($dir in 'src','support','include','Tests'){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $dir) -Recurse -File|Where-Object Extension -in '.h','.cpp'){
        $arguments=if($Check){@('--dry-run','--Werror',$file.FullName)}else{@('-i',$file.FullName)}
        & $formatter @arguments
        if($LASTEXITCODE -ne 0){$failed=$true}
    }
}
if($failed){throw 'Native formatting check failed.'}
