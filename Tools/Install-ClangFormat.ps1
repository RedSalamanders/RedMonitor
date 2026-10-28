<#
.SYNOPSIS
Installs the checksum-pinned native formatter beneath this repository's .build directory.
.DESCRIPTION
Extracts only clang-format.exe from the exact wheel recorded in Build/clang-format.json.
No Python or machine-wide installation is used. An existing matching formatter is reused.
An explicitly supplied wheel is always checked before reuse or extraction.
.PARAMETER WheelPath
Optional offline wheel. Its SHA256 must match the repository pin.
.OUTPUTS
Installation diagnostics. Failure throws; the existing formatter is preserved until staging succeeds.
.NOTES
Requires PowerShell 7 and network access unless WheelPath is supplied or a matching install exists.
Writes only guarded repository-local generated outputs. Used by CI and developer setup.
.EXAMPLE
./Tools/Install-ClangFormat.ps1
.EXAMPLE
./Tools/Install-ClangFormat.ps1 -WheelPath ./.build/downloads/clang-format.whl
#>
[CmdletBinding()]
param([string]$WheelPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../Build/Toolchain.psm1') -Force
$repo=Split-Path $PSScriptRoot -Parent
$pin=Get-Content -LiteralPath (Join-Path $repo 'Build/clang-format.json') -Raw|ConvertFrom-Json
if($pin.version -notmatch '^\d+\.\d+\.\d+$' -or $pin.wheelSha256 -cnotmatch '^[0-9a-f]{64}$' -or
   $pin.entryPath -cne 'clang_format/data/bin/clang-format.exe'){throw 'Invalid formatter pin.'}
$cache=Assert-RedMonitorOutputPath (Join-Path $repo '.build/format')
$executable=Assert-RedMonitorOutputPath (Join-Path $cache $pin.entryPath)
if((Test-Path -LiteralPath $executable) -and ((Get-Item -LiteralPath $executable -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
    throw 'Formatter output cannot be a reparse point.'
}
function Test-PinnedFormatter([string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
    $version=@(& $Path --version)
    return $LASTEXITCODE -eq 0 -and ($version -join '') -match ('^clang-format version '+[regex]::Escape($pin.version)+'(?:\s|$)')
}
if($WheelPath){
    $WheelPath=[IO.Path]::GetFullPath($WheelPath)
    if((Get-FileHash -LiteralPath $WheelPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pin.wheelSha256){throw 'Formatter wheel SHA256 does not match the repository pin.'}
}
if(Test-PinnedFormatter $executable){Write-Host "clang-format $($pin.version) is ready: $executable";return}
[void][IO.Directory]::CreateDirectory($cache)
$null=Assert-RedMonitorOutputPath $cache
$downloaded=$false
$stage=Assert-RedMonitorOutputPath (Join-Path $cache ('staging-'+[guid]::NewGuid().ToString('N')))
try{
    if(-not $WheelPath){
        $index=Invoke-RestMethod -Uri 'https://pypi.org/simple/clang-format/' -Headers @{Accept='application/vnd.pypi.simple.v1+json'}
        $candidates=@($index.files|Where-Object{$_.hashes.sha256 -ceq $pin.wheelSha256})
        if($candidates.Count -ne 1){throw 'Package index must contain exactly one checksum-pinned formatter wheel.'}
        $WheelPath=Assert-RedMonitorOutputPath (Join-Path $cache ('download-'+[guid]::NewGuid().ToString('N')+'.whl'))
        $downloaded=$true
        Invoke-WebRequest -Uri $candidates[0].url -OutFile $WheelPath
    }
    if((Get-FileHash -LiteralPath $WheelPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pin.wheelSha256){throw 'Formatter wheel SHA256 does not match the repository pin.'}
    [void][IO.Directory]::CreateDirectory($stage)
    $null=Assert-RedMonitorOutputPath $stage
    $stagedExe=Assert-RedMonitorOutputPath (Join-Path $stage 'clang-format.exe')
    $archive=[IO.Compression.ZipFile]::OpenRead($WheelPath)
    try{
        $entry=$archive.GetEntry($pin.entryPath)
        if(-not $entry){throw 'Pinned formatter wheel is missing clang-format.exe.'}
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$stagedExe,$false)
    }finally{$archive.Dispose()}
    if(-not(Test-PinnedFormatter $stagedExe)){throw 'Extracted formatter version does not match the repository pin.'}
    [void][IO.Directory]::CreateDirectory((Split-Path $executable -Parent))
    $null=Assert-RedMonitorOutputPath $executable
    Move-Item -LiteralPath $stagedExe -Destination $executable -Force
    Write-Host "Installed clang-format $($pin.version): $executable"
}finally{
    if($downloaded -and (Test-Path -LiteralPath $WheelPath)){
        $null=Assert-RedMonitorOutputPath $WheelPath
        Remove-Item -LiteralPath $WheelPath
    }
    if(Test-Path -LiteralPath $stage){
        $null=Assert-RedMonitorOutputPath $stage
        $stagedExe=Join-Path $stage 'clang-format.exe'
        if(Test-Path -LiteralPath $stagedExe){Remove-Item -LiteralPath $stagedExe}
        Remove-Item -LiteralPath $stage
    }
}
