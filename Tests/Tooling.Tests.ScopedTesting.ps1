<# .SYNOPSIS Exercises the product's real scoped runner in isolated Git and recording fixtures. #>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $root 'Build/ScopedTesting.psm1')
$run=Assert-RedMonitorOutputPath (Join-Path $root ('.build/scoped-tooling-tests/'+[guid]::NewGuid().ToString('N')))
$fixture=Join-Path $run 'repository'
[void][IO.Directory]::CreateDirectory($fixture)
$passed=0
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Case([string]$Name,[scriptblock]$Body){& $Body;$script:passed++;Write-Host "PASS $Name"}
function Put([string]$Name,[string]$Text){
    $path=Join-Path $fixture $Name
    [void][IO.Directory]::CreateDirectory((Split-Path $path))
    [IO.File]::WriteAllText($path,$Text,[Text.UTF8Encoding]::new($false))
}
function Invoke-FixtureGit([string[]]$Arguments){
    & git -C $fixture @Arguments *> $null
    if($LASTEXITCODE){throw "Fixture Git failed: $Arguments"}
}
function Checkpoint {
    Invoke-FixtureGit @('add','-A')
    Invoke-FixtureGit @('commit','--allow-empty','-qm','fixture checkpoint')
    Invoke-FixtureGit @('update-ref','refs/remotes/origin/main','HEAD')
}
function Calls {
    $path=Join-Path $fixture '.build/calls.txt'
    if(Test-Path -LiteralPath $path){ Get-Content -LiteralPath $path }
}
function Invoke-Runner([string[]]$Arguments=@()) {
    $calls=Join-Path $fixture '.build/calls.txt'
    if(Test-Path -LiteralPath $calls){[IO.File]::Delete($calls)}
    $start=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in @('-NoProfile','-NonInteractive','-File',(Join-Path $fixture 'Test-Changes.ps1'),'-BaseRef','origin/main')+$Arguments){
        $start.ArgumentList.Add($argument)
    }
    $child=[Diagnostics.Process]::Start($start)
    try{
        $stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync()
        if(-not $child.WaitForExit(90000)){$child.Kill($true);throw 'Owned scoped runner fixture timed out.'}
        $text=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $run ([guid]::NewGuid().ToString('N')+'.log')),$text)
        [pscustomobject]@{exit=$child.ExitCode;text=$text}
    }finally{$child.Dispose()}
}
function Snapshot-Attempts {
    $folder = Join-Path $fixture '.build/validation-evidence/independent'
    return (@(Get-ChildItem -LiteralPath $folder -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join '|')
}

$manifest=Read-ScopedTestManifest -Root $root -SkipProjectRules
Case 'product scope data preserves the affected lanes and the active native inventory' {
    Require ((Assert-ScopedTestNames -Root $root -Manifest $manifest) -eq 9) 'Native inventory lost one of the imported test seams.'
    Require ((Get-ScopedTestPlan -Manifest $manifest -ChangedPaths @()).scopes.Count -eq 0) 'An empty change selected work.'
    foreach ($path in @('Tests/Fixtures/README.md','Tests/Data/日本語.md','src/unknown.md','Specs/runtime.schema.json')) {
        $plan = Get-ScopedTestPlan -Manifest $manifest -ChangedPaths @($path) -Configuration Debug
        Require ('Regression' -cin $plan.scopes -and 'LiveEtw' -cnotin $plan.scopes -and 'ContainedInstallation' -cnotin $plan.scopes) "Wrong native scope for $path."
    }
}
foreach($path in @('Test-Changes.ps1','Build/Toolchain.psm1','Build/IndependentValidation.psm1',
    'Build/Formatting.psm1','Build/ScopedTesting.psm1','Build/TestRunEvidence.psm1','Tools/Invoke-ValidationScope.ps1',
    '.ci/project.json','Tests/test-scopes.json')){
    Put $path ([IO.File]::ReadAllText((Join-Path $root $path)))
}
$clone=& git -c core.longpaths=true clone --quiet --no-hardlinks (Join-Path $root '.ci-engine') (Join-Path $fixture '.ci-engine') 2>&1
if($LASTEXITCODE){throw "Owned engine fixture clone failed: $clone"}
Put '.gitignore' (".build/",".ci-engine/" -join [Environment]::NewLine)
Put 'README.md' '# Fixture guide'
Put 'src/runtime.cpp' 'initial runtime source'
Put 'CHANGELOG.md' ('# Changelog'+[Environment]::NewLine+[Environment]::NewLine+'## Unreleased'+[Environment]::NewLine)
Put 'Changes/README.md' '# Fragment guide'
Put 'Tests/native-test-files.json' '[]'
Import-Module (Join-Path $root 'Build/Formatting.psm1') -Scope Local
$null=Get-RedMonitorClangFormat -Root $root
[void][IO.Directory]::CreateDirectory((Join-Path $fixture '.build/shared-format'))
[IO.File]::Copy((Join-Path $root '.build/shared-format/clang-format.whl'),(Join-Path $fixture '.build/shared-format/clang-format.whl'))

$stub=@'
param([switch]$Check,[string]$Configuration,[string]$Platform,[switch]$PassThru,[string]$PackageDirectory)
$root=$PSScriptRoot
if((Split-Path $root -Leaf) -eq 'Tests'){$root=Split-Path -Parent $root}
$name=[IO.Path]::GetRelativePath($root,$PSCommandPath).Replace('\','/')
[IO.File]::AppendAllText((Join-Path $root '.build/calls.txt'),("$name|$Configuration|$Platform"+[Environment]::NewLine))
if((Test-Path (Join-Path $root '.build/fail')) -and [IO.File]::ReadAllText((Join-Path $root '.build/fail')) -ceq $name){exit 19}
if($name -ceq 'validate.ps1' -and (Test-Path (Join-Path $root '.build/mutate'))){
    [IO.File]::AppendAllText((Join-Path $root 'src/runtime.cpp'),' concurrent edit')
}
if($name -ceq 'build.ps1'){
    $manifest=Get-Content (Join-Path $root 'Tests/test-scopes.json') -Raw|ConvertFrom-Json
    foreach($relative in @('RedMonitor.exe')+@($manifest.runtimeFiles)){
        $path=Join-Path $root ".build/$Platform/$Configuration/$relative"
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        [IO.File]::WriteAllText($path,'stable recording-only artifact')
    }
}
if($PassThru){[pscustomobject]@{extracted=(Join-Path $root '.build/synthetic-package')}}
exit 0
'@
foreach($path in @('validate.ps1','format.ps1','Tests/Tooling.Tests.ps1','build.ps1','package.ps1','Tests/Tooling.Tests.Installation.ps1')){
    Put $path $stub
}
# Keep the real public scoped routing. Replace its low-level process-launching tail in the recording fixture only.
$test=[IO.File]::ReadAllText((Join-Path $root 'test.ps1'))
$marker='if(-not $SkipBuild){& (Join-Path $PSScriptRoot'
$index=$test.IndexOf($marker,[StringComparison]::Ordinal)
Require ($index -gt 0) 'Cannot identify the direct runtime boundary in test.ps1.'
$fixtureTail=@'
$fixtureOutput=Join-Path $PSScriptRoot '.build'
[IO.File]::AppendAllText((Join-Path $fixtureOutput 'calls.txt'),
    ("test.ps1|$Configuration|$Platform|$($IncludeLiveEtw.IsPresent)"+[Environment]::NewLine))
$failure=Join-Path $fixtureOutput 'fail'
if((Test-Path -LiteralPath $failure) -and [IO.File]::ReadAllText($failure) -ceq 'test.ps1'){throw 'synthetic runtime failure'}
} finally { Exit-ScopedProfileLease $profileLease }
'@
Put 'test.ps1' ($test.Substring(0,$index)+$fixtureTail)
Invoke-FixtureGit @('init','-q','-b','main')
foreach($setting in @(@('user.name','Scoped fixture'),@('user.email','fixture@example.invalid'),
    @('core.autocrlf','false'),@('commit.gpgsign','false'),@('core.hooksPath',(Join-Path $fixture '.git/no-hooks')))){Invoke-FixtureGit (@('config')+$setting)}
Checkpoint

Case 'the real entry point explains six profiles and executes nothing for an empty change' {
    $result=Invoke-Runner @('-Explain','-Mode','PrePush')
    Require ($result.exit -eq 0 -and @(Calls).Count -eq 0) $result.text
    foreach($configuration in @('Debug','Release','ASan Debug')){
        Require ($result.text.Contains("PrePush profile x64 $configuration") -and
            $result.text.Contains("PrePush profile ARM64 $configuration (build only)")) "Missing PrePush profile $configuration"
    }
    $none=Invoke-Runner
    Require ($none.exit -eq 0 -and $none.text.Contains('NOTHING_SELECTED') -and @(Calls).Count -eq 0) $none.text
}
Case 'owned prose runs all independent attempts and keeps native gates out' {
    Put 'README.md' '# Changed fixture guide'
    $result=Invoke-Runner
    $paths=@(Calls|ForEach-Object {($_ -split '\|')[0]})
    Require ($result.exit -eq 0 -and $result.text.Contains('PROSE_CHECKS_PASSED')) $result.text
    Require (($paths -join ',') -ceq 'validate.ps1,format.ps1,Tests/Tooling.Tests.ps1') "Unexpected prose operations: $paths"
    Checkpoint
}
Case 'malformed fragments fail before independent or native side effects' {
    Put 'Changes/2026-11-23-invalid.md' 'missing fragment bullet'
    $result=Invoke-Runner
    Require ($result.exit -ne 0 -and @(Calls).Count -eq 0) $result.text
    [IO.File]::Delete((Join-Path $fixture 'Changes/2026-11-23-invalid.md'))
}
Case 'affected native input selects the ordinary regression and publishes its canonical report' {
    Put 'src/runtime.cpp' 'changed runtime source'
    $result=Invoke-Runner
    Require ($result.exit -eq 0 -and $result.text.Contains('PASSED Regression')) $result.text
    Require (@(Calls|Where-Object {$_ -ceq 'test.ps1|Debug|x64|False'}).Count -eq 1) 'Regression did not execute once.'
    Require (@(Calls|Where-Object {$_ -like '*Installation*' -or $_ -like 'package.ps1*'}).Count -eq 0) 'Affected selected installation.'
    Checkpoint
}
Case 'Full Release runs live transport, packaging and installation once' {
    $result=Invoke-Runner @('-Mode','Full','-Configuration','Release')
    Require ($result.exit -eq 0 -and $result.text.Contains('FULL_PASSED')) $result.text
    Require (@(Calls|Where-Object {$_ -ceq 'test.ps1|Release|x64|True'}).Count -eq 1) 'Full lost the combined regression/live path.'
    Require (@(Calls|Where-Object {$_ -ceq 'package.ps1|Release|x64'}).Count -eq 1 -and
        @(Calls|Where-Object {$_ -like 'Tests/Tooling.Tests.Installation.ps1|*'}).Count -eq 1) 'Full lost contained installation.'
}
Case 'a later runtime failure preserves all completed independent attempts on the replay' {
    Put '.build/fail' 'test.ps1'
    $result=Invoke-Runner @('-Mode','Full','-Force')
    Require ($result.exit -ne 0 -and $result.text.Contains('synthetic runtime failure')) $result.text
    $before=Snapshot-Attempts
    [IO.File]::Delete((Join-Path $fixture '.build/fail'))
    $result=Invoke-Runner @('-Mode','Full')
    foreach($scope in @('Validation','Format','Tooling')){Require ($result.text.Contains("REUSED $scope")) $result.text}
    Require ($result.exit -eq 0 -and (Snapshot-Attempts) -ceq $before) 'Independent attempt history changed.'
    Require (@(Calls|Where-Object {$_ -ceq 'test.ps1|Debug|x64|True'}).Count -eq 1) 'Independent reuse dropped native work.'
}
Case 'a forced independent failure revokes shared reuse before runtime' {
    Put '.build/fail' 'format.ps1'
    $result=Invoke-Runner @('-Mode','Full','-Force')
    Require ($result.exit -ne 0 -and @(Calls|Where-Object {$_ -like 'test.ps1*'}).Count -eq 0) $result.text
    $latest=Get-Content (Join-Path $fixture '.build/validation-evidence/independent/Format/latest.json') -Raw|ConvertFrom-Json
    Require ($latest.status -ceq 'failed') 'The failed attempt retained a green state.'
    [IO.File]::Delete((Join-Path $fixture '.build/fail'))
    $result=Invoke-Runner @('-Mode','Full')
    Require ($result.exit -eq 0 -and @(Calls|Where-Object {$_ -like 'format.ps1*'}).Count -eq 1) $result.text
}
Case 'package and installation failures reach the caller' {
    foreach($name in 'package.ps1','Tests/Tooling.Tests.Installation.ps1'){
        Put '.build/fail' $name
        $result=Invoke-Runner @('-Mode','Full','-Configuration','Release')
        Require ($result.exit -ne 0 -and -not $result.text.Contains('FULL_PASSED')) $result.text
    }
    [IO.File]::Delete((Join-Path $fixture '.build/fail'))
}
Case 'a source edit during prose validation refuses success' {
    Put 'README.md' '# Concurrent edit fixture'
    Put '.build/mutate' 'mutate source during validation'
    $result=Invoke-Runner
    Require ($result.exit -ne 0 -and $result.text.Contains('Inputs changed during independent validation') -and
        -not $result.text.Contains('PROSE_CHECKS_PASSED')) $result.text
    Require (@(Calls|Where-Object {$_ -like 'test.ps1*'}).Count -eq 0) 'Mixed-source native execution was attempted.'
    [IO.File]::Delete((Join-Path $fixture '.build/mutate'))
}
Case 'actual ignored engine participates in source and build identity independently of file discovery' {
    $fixture=Join-Path $run 'engine-input-project'
    [void][IO.Directory]::CreateDirectory($fixture)
    [void][IO.Directory]::CreateDirectory((Join-Path $fixture '.ci'))
    Put '.gitignore' ".build/`n.ci-engine/`n"
    Put '.ci/project.json' ([IO.File]::ReadAllText((Join-Path $root '.ci/project.json')))
    Put 'runtime.cpp' 'synthetic source'
    Invoke-FixtureGit @('init','--quiet')
    $engine=Join-Path $fixture '.ci-engine'
    $clone=& (Get-Command git -CommandType Application | Select-Object -First 1).Source clone --quiet --no-hardlinks (Join-Path $root '.ci-engine') $engine 2>&1
    if($LASTEXITCODE){throw "Owned engine fixture clone failed: $clone"}
    $before=Get-RedMonitorSourceSnapshot $fixture
    Require ($before.EngineInputsIdentity -match '^[0-9a-f]{64}$') 'Actual engine input digest was missing'
    if([OperatingSystem]::IsWindows()){Require ((Get-RedMonitorSourceIdentity $fixture.ToUpperInvariant()) -ceq $before.Identity) 'Windows casing aliases invalidated source identity'}
    Require (@($before.Files.Keys|Where-Object {$_ -like '.ci-engine/*'}).Count -eq 0) 'Engine identity polluted product file discovery'
    [void][IO.Directory]::CreateDirectory((Join-Path $engine '.build'))
    [IO.File]::WriteAllText((Join-Path $engine '.build/synthetic.json'), '{"generated":true}')
    Require ((Get-RedMonitorSourceIdentity $fixture) -ceq $before.Identity) 'Generated engine output invalidated evidence'
    $policy=Join-Path $engine 'Tools/Modules/Ci.Policy.psm1'
    $original=[IO.File]::ReadAllBytes($policy)
    try{
        [IO.File]::AppendAllText($policy,"`n# Synthetic changed engine implementation.`n")
        $reason=''
        try{$null=Get-RedMonitorSourceIdentity $fixture}catch{$reason=$_.Exception.Message}
        Require ($reason.Contains('Local engine checkout must be clean')) 'Modified ignored engine retained reusable evidence'
    }finally{[IO.File]::WriteAllBytes($policy,$original)}
    Require ((Get-RedMonitorSourceIdentity $fixture) -ceq $before.Identity) 'Restored exact engine did not recover its identity'
}
Case 'complete independent identity detects source and discovery-environment changes without rewriting input' {
    # Keep fixture modules inside fixture child processes; importing one here would
    # replace same-named commands in the real caller after this tooling script returns.
    Import-Module (Join-Path $root 'Build/IndependentValidation.psm1')
    $before=Get-RedMonitorIndependentIdentity -Root $fixture
    $environment=[Environment]::GetEnvironmentVariable('CI_NATIVE_BUILDS_DISABLED','Process')
    try{
        [Environment]::SetEnvironmentVariable('CI_NATIVE_BUILDS_DISABLED','synthetic-changed-state','Process')
        Require ((Get-RedMonitorIndependentIdentity -Root $fixture) -cne $before) 'CI discovery environment was absent from independent identity'
    }finally{
        if($null -eq $environment){Remove-Item Env:CI_NATIVE_BUILDS_DISABLED -ErrorAction SilentlyContinue}
        else{[Environment]::SetEnvironmentVariable('CI_NATIVE_BUILDS_DISABLED',$environment,'Process')}
    }
    $readme=Join-Path $fixture 'README.md';$original=[IO.File]::ReadAllBytes($readme)
    try{
        [IO.File]::AppendAllText($readme,' changed validator prose')
        Require ((Get-RedMonitorIndependentIdentity -Root $fixture) -cne $before) 'Validator prose bytes were absent from independent identity'
    }finally{[IO.File]::WriteAllBytes($readme,$original)}
    Require ((Get-RedMonitorIndependentIdentity -Root $fixture) -ceq $before) 'Input acquisition mutated source or caller environment'
}

Write-Host "PASS $passed affected-planning and public runner cases. Recording fixtures retained at $run."
$global:LASTEXITCODE=0
