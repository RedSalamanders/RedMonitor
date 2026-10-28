<#
.SYNOPSIS
Verifies formatter package rejection, version enforcement and read-only strict checks.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'Build/Toolchain.psm1') -Force
$fixture=Assert-RedMonitorOutputPath (Join-Path $repo ('.build/tooling-tests/formatter-'+[guid]::NewGuid().ToString('N')))
foreach($directory in 'Tools','Build','src','support','include','Tests','.build/format/clang_format/data/bin'){
    [void][IO.Directory]::CreateDirectory((Join-Path $fixture $directory))
}
foreach($path in 'Tools/Install-ClangFormat.ps1','Build/Toolchain.psm1','Build/Formatting.psm1','Build/clang-format.json','format.ps1','.clang-format'){
    Copy-Item -LiteralPath (Join-Path $repo $path) -Destination (Join-Path $fixture $path)
}
$pin=Get-Content -LiteralPath (Join-Path $repo 'Build/clang-format.json') -Raw|ConvertFrom-Json
$cached=Join-Path $fixture ('.build/format/'+$pin.entryPath)
$wheel=Join-Path $fixture 'corrupt.whl'
[IO.File]::WriteAllText($wheel,'A corrupt package must never be extracted.')
[IO.File]::WriteAllText($cached,'An existing formatter must survive rejected input.')
$before=(Get-FileHash -LiteralPath $cached).Hash
$output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'Tools/Install-ClangFormat.ps1') -WheelPath $wheel 2>&1)
if($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'SHA256 does not match'){throw 'Corrupt formatter wheel was not rejected by its checksum.'}
if((Get-FileHash -LiteralPath $cached).Hash -cne $before){throw 'Rejected wheel replaced the existing formatter.'}
if(@(Get-ChildItem -LiteralPath (Join-Path $fixture '.build/format') -Directory -Filter 'staging-*').Count){throw 'Rejected wheel reached extraction staging.'}
$installed=Join-Path $repo ('.build/format/'+$pin.entryPath)
if(-not(Test-Path -LiteralPath $installed -PathType Leaf)){throw 'Install the pinned formatter before running its behavior tests.'}
Copy-Item -LiteralPath $installed -Destination $cached -Force
$fixturePin=Join-Path $fixture 'Build/clang-format.json'
$pin.version='0.0.0'
$pin|ConvertTo-Json|Set-Content -LiteralPath $fixturePin -Encoding utf8
$output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'format.ps1') -Check 2>&1)
if($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'Formatting requires clang-format 0\.0\.0'){throw 'Mismatched formatter version was not rejected before source inspection.'}
Copy-Item -LiteralPath (Join-Path $repo 'Build/clang-format.json') -Destination $fixturePin -Force
$source=Join-Path $fixture 'src/FormatterFixture.cpp'
[IO.File]::WriteAllText($source,"int main(){return 0;}`n")
$sourceBefore=(Get-FileHash -LiteralPath $source).Hash
$output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'format.ps1') -Check 2>&1)
if($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'Native formatting check failed'){throw 'Strict formatting check accepted deliberately malformed style.'}
if((Get-FileHash -LiteralPath $source).Hash -cne $sourceBefore){throw 'Read-only formatter check changed source bytes.'}
$output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'format.ps1') 2>&1)
if($LASTEXITCODE -ne 0){throw "Explicit formatting failed: $($output -join ' ')"}
if((Get-FileHash -LiteralPath $source).Hash -ceq $sourceBefore){throw 'Explicit formatting did not repair the fixture.'}
$output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'format.ps1') -Check 2>&1)
if($LASTEXITCODE -ne 0){throw "Formatted fixture did not pass the unchanged strict check: $($output -join ' ')"}
Write-Host 'PASS: corrupt wheel refusal, existing-install preservation, exact version and read-only strict formatting'
