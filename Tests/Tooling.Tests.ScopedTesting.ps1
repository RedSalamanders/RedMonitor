<#
.SYNOPSIS Exercises affected planning and the actual public wrapper in isolated Git/process fixtures.
.NOTES Native entrypoints are recording fixtures, never native acceptance. All outputs remain below .build.
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$run=Assert-RedMonitorOutputPath (Join-Path $root ('.build/scoped-tooling-tests/'+[guid]::NewGuid().ToString('N')))
$fixture=Join-Path $run 'repository'
[void][IO.Directory]::CreateDirectory($fixture)
$passed=0
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Case([string]$Name,[scriptblock]$Body){& $Body;$script:passed++;Write-Host "PASS $Name"}
function Put([string]$Name,[string]$Text){$path=Join-Path $fixture $Name;[void][IO.Directory]::CreateDirectory((Split-Path $path));[IO.File]::WriteAllText($path,$Text,[Text.UTF8Encoding]::new($false))}
function Git([string[]]$Arguments){& (Get-Command git -CommandType Application | Select-Object -First 1).Source -C $fixture @Arguments *> $null;if($LASTEXITCODE){throw "Fixture Git failed: $Arguments"}}
function Checkpoint {Git @('add','-A');Git @('commit','--allow-empty','-qm','fixture checkpoint');Git @('update-ref','refs/remotes/origin/main','HEAD')}
function Calls {if(Test-Path (Join-Path $fixture '.build/calls.txt')){@(Get-Content (Join-Path $fixture '.build/calls.txt'))}else{@()}}
function Invoke-Runner([string]$Mode='Affected',[switch]$Explain){
    $calls=Join-Path $fixture '.build/calls.txt';if(Test-Path $calls){[IO.File]::Delete($calls)}
    $start=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in @('-NoProfile','-File',(Join-Path $fixture 'Test-Changes.ps1'),'-Mode',$Mode)){$start.ArgumentList.Add($argument)}
    if($Explain){$start.ArgumentList.Add('-Explain')}
    $child=[Diagnostics.Process]::Start($start)
    try{
        $stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync()
        if(-not $child.WaitForExit(30000)){$child.Kill($true);throw 'Owned public-wrapper fixture timed out.'}
        $text=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $run ([guid]::NewGuid().ToString('N')+'.log')),$text)
        return [pscustomobject]@{exit=$child.ExitCode;text=$text}
    }finally{$child.Dispose()}
}
foreach($path in @('Test-Changes.ps1','Build/Toolchain.psm1','Build/AgentGuidance.psm1','Tools/Test-Changelog.ps1','Tools/Modules/Documentation/Changelog.psm1')){
    Put $path ([IO.File]::ReadAllText((Join-Path $root $path)))
}
Put '.gitignore' ".build/`n"
Put 'README.md' '# Fixture guide'
Put 'src/runtime.cpp' 'initial runtime source'
Put 'CHANGELOG.md' "# Changelog`n`n## Unreleased`n"
Put 'Changes/README.md' '# Fragment guide'
[void][IO.Directory]::CreateDirectory((Join-Path $fixture '.build'))
$stub=@'
param([switch]$Check,[string]$Configuration,[string]$Platform,[switch]$IncludeLiveEtw,[switch]$PassThru,[string]$PackageDirectory)
$root=$PSScriptRoot
if((Split-Path $root -Leaf) -eq 'Tests'){$root=Split-Path $root}
$name=[IO.Path]::GetRelativePath($root,$PSCommandPath).Replace('\','/')
[IO.File]::AppendAllText((Join-Path $root '.build/calls.txt'),($name+'|'+$Configuration+'|'+$Platform+'|'+$IncludeLiveEtw.IsPresent+"`n"))
if((Test-Path (Join-Path $root '.build/fail')) -and [IO.File]::ReadAllText((Join-Path $root '.build/fail')) -ceq $name){exit 19}
if($name -ceq 'validate.ps1' -and (Test-Path (Join-Path $root '.build/mutate'))){[IO.File]::AppendAllText((Join-Path $root 'src/runtime.cpp'),' concurrent edit')}
if($PassThru){[pscustomobject]@{extracted=(Join-Path $root '.build/synthetic-package')}}
exit 0
'@
foreach($path in @('validate.ps1','format.ps1','Tests/Tooling.Tests.ps1','test.ps1','build.ps1','package.ps1','Tests/Tooling.Tests.Installation.ps1')){Put $path $stub}
Git @('init','-q','-b','main')
foreach($setting in @(@('user.name','Scoped fixture'),@('user.email','fixture@example.invalid'),@('core.autocrlf','false'),@('commit.gpgsign','false'),@('core.hooksPath',(Join-Path $fixture '.git/no-hooks')))){Git (@('config')+$setting)}
Checkpoint
Case 'no-work and explain never execute checks or claim qualification' {
    $result=Invoke-Runner
    Require ($result.exit -eq 0 -and $result.text.Contains('NOTHING_SELECTED; repository NOT_EVALUATED') -and @(Calls).Count -eq 0) $result.text
    Put 'README.md' '# Changed guide'
    $result=Invoke-Runner -Explain
    Require ($result.exit -eq 0 -and @(Calls).Count -eq 0 -and -not $result.text.Contains('PROSE_CHECKS_PASSED')) $result.text
}
Case 'owned prose runs real fragment validation and independent checks without native entrypoints' {
    Put 'Specs/Testing/fixture.md' '# Fixture contract'
    Put 'Changes/2026-11-09-fixture.md' '- Fixture prose change.'
    Require ((Get-RedMonitorChangePlan $fixture).kind -ceq 'Prose') 'Owned prose selected native work'
    $result=Invoke-Runner
    Require ($result.exit -eq 0 -and $result.text.Contains('PROSE_CHECKS_PASSED; repository NOT_EVALUATED')) $result.text
    Require ((@(Calls) -join ',') -ceq 'validate.ps1|||False,format.ps1|||False,Tests/Tooling.Tests.ps1|||False') 'Native work ran or independent checks were omitted'
}
Case 'malformed fragments fail before prose success or native work' {
    Put 'Changes/2026-11-09-fixture.md' 'not a valid bullet'
    $result=Invoke-Runner
    Require ($result.exit -ne 0 -and -not $result.text.Contains('PROSE_CHECKS_PASSED') -and @(Calls).Count -eq 0) $result.text
    Put 'Changes/2026-11-09-fixture.md' '- Fixture prose change.'
    Checkpoint
}
Case 'cumulative committed code followed by prose retains Debug execution' {
    Put 'src/runtime.cpp' 'changed runtime source';Git @('add','src/runtime.cpp');Git @('commit','-qm','native change')
    Put 'README.md' '# Later documentation'
    $result=Invoke-Runner
    Require ($result.exit -eq 0 -and $result.text.Contains('SELECTED_DEBUG_PASSED')) $result.text
    Require (@(Calls|Where-Object {$_ -ceq 'test.ps1|Debug||False'}).Count -eq 1) 'Cumulative native work was hidden by prose'
    Checkpoint
}
Case 'independent staged and working discovery retains a staged native edit reverted only on disk' {
    $original=[IO.File]::ReadAllText((Join-Path $fixture 'src/runtime.cpp'))
    Put 'src/runtime.cpp' 'staged native change';Git @('add','src/runtime.cpp');Put 'src/runtime.cpp' $original
    Require ((Get-RedMonitorChangePlan $fixture).kind -ceq 'Native') 'Staged native edit disappeared'
    Git @('add','src/runtime.cpp')
}
Case 'rename sides, deletion, Unicode fixtures and schema inputs stay native' {
    [IO.File]::Move((Join-Path $fixture 'src/runtime.cpp'),(Join-Path $fixture 'Specs/moved.md'))
    $plan=Get-RedMonitorChangePlan $fixture
    Require ($plan.kind -ceq 'Native' -and 'src/runtime.cpp' -cin $plan.paths -and 'Specs/moved.md' -cin $plan.paths) 'Rename lost its native side'
    [IO.File]::Move((Join-Path $fixture 'Specs/moved.md'),(Join-Path $fixture 'src/runtime.cpp'))
    foreach($path in @('Tests/Fixtures/README.md','Tests/Data/日本語.md','src/unknown.md','Specs/runtime.schema.json')){
        Put $path 'new runtime input'
        $plan=Get-RedMonitorChangePlan $fixture
        Require ($plan.kind -ceq 'Native' -and $path -cin $plan.paths) "Unknown/runtime input was treated as prose: $path"
        [IO.File]::Delete((Join-Path $fixture $path))
    }
}
Case 'missing comparison retains native work instead of silently selecting nothing' {
    Git @('update-ref','-d','refs/remotes/origin/main')
    $plan=Get-RedMonitorChangePlan $fixture
    Require ($plan.kind -ceq 'Native' -and $plan.reason.Contains('Comparison unavailable')) 'Missing base did not fail conservatively'
    $result=Invoke-Runner
    Require ($result.exit -eq 0 -and @(Calls|Where-Object {$_ -ceq 'test.ps1|Debug||False'}).Count -eq 1) $result.text
    Checkpoint
}
Case 'explicit Full and PrePush retain every local profile, live transport and installation obligation on unchanged input' {
    foreach($mode in @('Full','PrePush')){
        $result=Invoke-Runner $mode
        Require ($result.exit -eq 0 -and $result.text.Contains('LOCAL_OBLIGATIONS_PASSED')) $result.text
        $calls=@(Calls)
        foreach($configuration in @('Debug','Release','ASan Debug')){
            Require (@($calls|Where-Object {$_ -ceq "test.ps1|$configuration||True"}).Count -eq 1) "$mode omitted $configuration native tests/live ETW"
            Require (@($calls|Where-Object {$_ -ceq "build.ps1|$configuration|ARM64|False"}).Count -eq 1) "$mode omitted $configuration ARM64 cross-build"
        }
        Require (@($calls|Where-Object {$_ -like 'package.ps1|*'}).Count -eq 1 -and @($calls|Where-Object {$_ -like 'Tests/Tooling.Tests.Installation.ps1|*'}).Count -eq 1) "$mode omitted packaging/installation"
    }
}
Case 'nonzero independent, runtime, build and package commands cannot become success' {
    foreach($command in @('validate.ps1','format.ps1','Tests/Tooling.Tests.ps1','test.ps1','build.ps1','package.ps1','Tests/Tooling.Tests.Installation.ps1')){
        Put '.build/fail' $command
        $result=Invoke-Runner Full
        Require ($result.exit -ne 0 -and -not $result.text.Contains('LOCAL_OBLIGATIONS_PASSED') -and $result.text.Contains('Validation failed: '+$command)) "Nonzero exit was lost: $command $($result.text)"
    }
    [IO.File]::Delete((Join-Path $fixture '.build/fail'))
}
Case 'a native edit during prose validation refuses success' {
    Put 'README.md' '# Prose candidate'
    Put '.build/mutate' 'mutate source inside independent validation'
    $result=Invoke-Runner
    Require ($result.exit -ne 0 -and $result.text.Contains('Inputs changed during independent validation') -and -not $result.text.Contains('PROSE_CHECKS_PASSED')) $result.text
    Require (@(Calls|Where-Object {$_ -like 'test.ps1|*'}).Count -eq 0) 'Mixed-source native execution was attempted'
}
Write-Host "PASS $passed affected-planning/public-runner cases; recording fixtures only: $run"
$global:LASTEXITCODE=0
