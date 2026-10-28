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
$pin=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Build/clang-format.json') -Raw|ConvertFrom-Json
$repositoryFormatter=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/format/'+$pin.entryPath))
$installation=''
$pathFormatter=''
if(-not(Test-Path -LiteralPath $repositoryFormatter -PathType Leaf)){
    try {
        $msbuild=Get-RedMonitorMSBuild
        $installation=([IO.FileInfo]$msbuild).Directory.Parent.Parent.Parent.FullName
    } catch [System.Management.Automation.RuntimeException] {
        # Standalone LLVM remains supported when Visual Studio is absent.
        Write-Verbose "Visual Studio formatter discovery unavailable: $($_.Exception.Message)"
    }
    $command=Get-Command clang-format.exe -ErrorAction SilentlyContinue|Select-Object -First 1
    if($command){$pathFormatter=$command.Source}
}
$formatter=Find-RedMonitorClangFormat -VisualStudioInstallation $installation -PathFormatter $pathFormatter -RepositoryFormatter $repositoryFormatter
if((Get-Item -LiteralPath $formatter -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Formatter cannot be a reparse point.'}
$version=@(& $formatter --version)
if($LASTEXITCODE -ne 0 -or ($version -join '') -notmatch ('^clang-format version '+[regex]::Escape($pin.version)+'(?:\s|$)')){
    throw "Formatting requires clang-format $($pin.version). Run ./Tools/Install-ClangFormat.ps1. Found: $($version -join ' ')"
}
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
