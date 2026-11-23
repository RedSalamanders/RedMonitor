#Requires -Version 7.0
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$run = Assert-RedMonitorOutputPath (Join-Path $root ('.build/documentation-validation-tests/'+[guid]::NewGuid().ToString('N')))
$public = Join-Path $run 'public-entrypoint'
$publicChecks = 0

function Put([string]$Name,[string]$Text) {
    $path = Join-Path $run $Name
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path,$Text,[Text.UTF8Encoding]::new($false))
}
function Snapshot {
    return (@(Get-ChildItem -LiteralPath $run -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($run,$_.FullName)
        if ($_.PSIsContainer) { 'D:'+$relative+':'+$_.Attributes }
        else { 'F:'+$relative+':'+$_.LastWriteTimeUtc.Ticks+':'+(Get-FileHash -LiteralPath $_.FullName).Hash+':'+$_.Attributes }
    }) -join "`n")
}

foreach ($name in 'validate.ps1','validate-skills.ps1','Build/DocumentationValidation.psm1','Build/Toolchain.psm1',
    'Tools/Test-AgentGuidance.ps1','.ci/project.json','.agents/guidance.json') {
    Put ('public-entrypoint/'+$name) ([IO.File]::ReadAllText((Join-Path $root $name)))
}
foreach ($name in 'LICENSE.txt','README.md','capabilities.json','Specs/README.md','Specs/Plans/WIP/README.md',
    'Specs/Plans/Done/README.md','Specs/SourceImport/source-origin.json','vcpkg.json') {
    Put ('public-entrypoint/'+$name) $(if ($name.EndsWith('.json')) { '{}' } else { 'Fixture' })
}
foreach ($name in 'src/RedMonitor.vcxproj','Tests/MonitorTest.vcxproj') { Put ('public-entrypoint/'+$name) '<Project />' }
foreach ($name in 'Dependencies/DxUi.lock.json','vcpkg-tool.json') { Put ('public-entrypoint/'+$name) ('{"commit":"'+('0'*40)+'"}') }
Put 'public-entrypoint/AGENTS.md' '[example](.agents/skills/example/SKILL.md)'
Put 'public-entrypoint/.agents/skills/example/SKILL.md' "---`nname: example`ndescription: Use when validating a fixture.`n---`nRead the fixture."
Put 'public-entrypoint/CLAUDE.md' '[AGENTS.md](AGENTS.md)'
Put 'public-entrypoint/.github/copilot-instructions.md' '[AGENTS.md](../AGENTS.md)'

$engine = Join-Path $public '.ci-engine'
$clone = & git clone --quiet --no-hardlinks (Join-Path $root '.ci-engine') $engine 2>&1
if ($LASTEXITCODE -ne 0) { throw "Owned engine checkout failed: $clone" }
$pin = (Get-Content (Join-Path $public '.ci/project.json') -Raw | ConvertFrom-Json).engine.ref
$checkout = & git -C $engine checkout --quiet --detach $pin 2>&1
if ($LASTEXITCODE -ne 0) { throw "Owned engine pin failed: $checkout" }

function Expect-Public([string]$Name,[bool]$Accepted,[string]$ExpectedProblem='') {
    $before = Snapshot
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($argument in '-NoProfile','-NonInteractive','-File',(Join-Path $public 'validate.ps1')) { $start.ArgumentList.Add($argument) }
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $child = [Diagnostics.Process]::new(); $child.StartInfo = $start
    $started = $false
    try {
        if (-not $child.Start()) { throw 'Could not start the owned public-validator fixture.' }
        $started = $true
        $stdout = $child.StandardOutput.ReadToEndAsync(); $stderr = $child.StandardError.ReadToEndAsync()
        if (-not $child.WaitForExit(30000)) { throw 'Owned public-validator fixture timed out.' }
        if (-not [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($stdout,$stderr)).Wait(5000)) { throw 'Public-validator pipes did not close.' }
        $text = $stdout.Result+$stderr.Result
        if (($child.ExitCode -eq 0) -ne $Accepted) { throw "Public control '$Name' expected accepted=$Accepted`: $text" }
        if ($ExpectedProblem -and $text -notlike "*$ExpectedProblem*") { throw "Public control '$Name' rejected for the wrong reason: $text" }
        if ((Snapshot) -cne $before) { throw "Public validation wrote during '$Name'." }
        $script:publicChecks++
        Write-Host "PASS public guidance $Name"
    } finally {
        if ($started -and -not $child.HasExited) { $child.Kill($true); [void]$child.WaitForExit(5000) }
        $child.Dispose()
    }
}

$document = 'public-entrypoint/README.md'
Put 'public-entrypoint/Specs/contract name.md' '# Contract'
Put 'public-entrypoint/Specs/contract(v1).md' '# Contract'
Put $document 'Read [contract](Specs/contract%20name.md).'
Expect-Public 'accepts an encoded ordinary documentation link' $true
Put $document 'Read [contract](Specs/contract(v1).md (Owning contract)).'
Expect-Public 'accepts a balanced destination and title in ordinary documentation' $true
Put $document "Read [contract][owner].`n[owner]:`n  Specs/contract%20name.md"
Expect-Public 'accepts a continued ordinary documentation reference' $true
Put $document "Read [contract][owner].`n[owner]: Specs/missing.md"
Expect-Public 'rejects a missing ordinary documentation destination' $false 'missing local reference'
Put $document 'Read [contract][undefined].'
Expect-Public 'rejects an undefined ordinary documentation reference' $false 'Unresolved Markdown reference label'
Put $document ('Read [contract]('+([uri](Join-Path $run 'outside.md')).AbsoluteUri+').')
Expect-Public 'rejects an ordinary documentation link outside the repository' $false 'non-repository reference'
Put $document ('```text'+"`n[Example](missing.md)`n"+'```')
Expect-Public 'accepts a fenced illustration in ordinary documentation' $true

$inventory = Join-Path $public '.agents/guidance.json'
$inventoryText = [IO.File]::ReadAllText($inventory)
[IO.File]::Delete($inventory)
try { Expect-Public 'surfaces an engine guidance failure from full validation' $false '(G9)' }
finally { Put 'public-entrypoint/.agents/guidance.json' $inventoryText }
Write-Host "PASS $publicChecks read-only public documentation and guidance integration controls. Fixture: $run"
