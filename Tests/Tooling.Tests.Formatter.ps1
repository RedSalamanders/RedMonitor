<#
.SYNOPSIS
Verifies that format.ps1 formats only with the pinned engine formatter, refuses a missing or mismatched
engine, verifies without writing under -Check and formats its own selection.
.NOTES
The fixture is a fresh Git repository beneath .build with its own .ci-engine clone. It reuses this checkout's
verified formatter wheel, so it never downloads; the first call installs that wheel through the engine.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $repo 'Build/Formatting.psm1') -Force
$formatter=Get-RedMonitorClangFormat -Root $repo
if([IO.Path]::GetFullPath($formatter) -ine [IO.Path]::GetFullPath((Join-Path $repo '.build/shared-format/clang-format.exe'))){
    throw "The selected formatter is not the pinned engine install: $formatter"
}
$git=(Get-Command git -CommandType Application|Select-Object -First 1).Source
$fixture=Assert-RedMonitorOutputPath (Join-Path $repo ('.build/tooling-tests/formatter-'+[guid]::NewGuid().ToString('N')))
foreach($directory in '.ci','src','.build/shared-format'){[void][IO.Directory]::CreateDirectory((Join-Path $fixture $directory))}
foreach($path in 'format.ps1','.clang-format','.ci/project.json','.gitignore'){
    Copy-Item -LiteralPath (Join-Path $repo $path) -Destination (Join-Path $fixture $path)
}
Copy-Item -LiteralPath (Join-Path $repo '.build/shared-format/clang-format.whl') -Destination (Join-Path $fixture '.build/shared-format/clang-format.whl')
# A fixture without its own repository would let Git list the enclosing checkout instead.
& $git -C $fixture init -q
if($LASTEXITCODE){throw 'Fixture Git init failed.'}
function Invoke-Format([string[]]$Arguments){
    $output=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $fixture 'format.ps1') @Arguments 2>&1)
    [pscustomobject]@{exit=$LASTEXITCODE;text=($output -join "`n")}
}
$source=Join-Path $fixture 'src/FormatterFixture.cpp'
[IO.File]::WriteAllText($source,"int main(){return 0;}`n")
$sourceBefore=(Get-FileHash -LiteralPath $source).Hash

$result=Invoke-Format @('-Check')
if($result.exit -eq 0 -or $result.text -notmatch 'needs the shared CI engine'){throw "A missing engine was not refused: $($result.text)"}
$engine=Join-Path $fixture '.ci-engine'
$clone=& $git clone --quiet --no-hardlinks (Join-Path $repo '.ci-engine') $engine 2>&1
if($LASTEXITCODE){throw "Fixture engine clone failed: $clone"}
$pin=(Get-Content -LiteralPath (Join-Path $fixture '.ci/project.json') -Raw|ConvertFrom-Json).engine.ref
& $git -C $engine -c advice.detachedHead=false checkout -q --detach "$pin~1"
$result=Invoke-Format @('-Check')
if($result.exit -eq 0 -or $result.text -notmatch 'pins'){throw "A mismatched engine was not refused: $($result.text)"}
& $git -C $engine -c advice.detachedHead=false checkout -q --detach $pin

$result=Invoke-Format @('-Check')
if($result.exit -eq 0 -or $result.text -notmatch 'Needs formatting: src/FormatterFixture\.cpp'){throw "The strict check accepted unformatted source: $($result.text)"}
if((Get-FileHash -LiteralPath $source).Hash -cne $sourceBefore){throw 'The read-only check changed source bytes.'}
$result=Invoke-Format @()
if($result.exit -ne 0){throw "Formatting failed: $($result.text)"}
if((Get-FileHash -LiteralPath $source).Hash -ceq $sourceBefore){throw 'Formatting did not repair the fixture.'}
$result=Invoke-Format @('-Check')
if($result.exit -ne 0 -or $result.text -notmatch 'Checked 1 files\.'){throw "The formatted fixture did not pass the strict check: $($result.text)"}
Write-Host 'PASS: pinned engine formatter, missing and mismatched engine refusal, read-only check and formatting'
