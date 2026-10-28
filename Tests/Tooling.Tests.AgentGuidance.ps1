<#
.SYNOPSIS
Exercises skill structure, declared references, read-only validation and a real WIP-to-Done transition.
.DESCRIPTION
Pure header controls use memory. File controls retain an owned, unique .build fixture; no native code,
network, external links, desktop input or existing evidence cleanup is involved.
#>
#Requires -Version 7.0
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
Import-Module (Join-Path $root 'Build/AgentGuidance.psm1') -Force
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$prefix = "---`nname: example-skill`ndescription: Validate a fixture.`n---`n"
$cases = @(
    @{ Name='plain'; Text=$prefix+'Read the contract.'; Valid=$true },
    @{ Name='CRLF'; Text=($prefix+'Read.').Replace("`n","`r`n"); Valid=$true },
    @{ Name='single quote'; Text=$prefix.Replace('Validate a fixture.',"'It''s a fixture: 日本語.'")+'Read.'; Valid=$true },
    @{ Name='double quote'; Text=$prefix.Replace('Validate a fixture.','"Validate français."')+'Read.'; Valid=$true },
    @{ Name='double quoted date'; Text=$prefix.Replace('Validate a fixture.','"2026-10-28"')+'Read.'; Valid=$true },
    @{ Name='double quoted UTC timestamp'; Text=$prefix.Replace('Validate a fixture.','"2026-10-28T09:00:00Z"')+'Read.'; Valid=$true },
    @{ Name='double quoted offset timestamp'; Text=$prefix.Replace('Validate a fixture.','"2026-10-28T09:00:00+02:00"')+'Read.'; Valid=$true },
    @{ Name='plain timestamp requires quoting'; Text=$prefix.Replace('Validate a fixture.','2026-10-28T09:00:00Z')+'Read.'; Valid=$false },
    @{ Name='missing file'; Text=$null; Valid=$false },
    @{ Name='unfenced'; Text="name: example-skill`ndescription: Validate.`nRead."; Valid=$false },
    @{ Name='empty body'; Text=$prefix; Valid=$false },
    @{ Name='duplicate name'; Text=$prefix.Replace('description:',"name: wrong`ndescription:")+'Read.'; Valid=$false },
    @{ Name='duplicate description'; Text=$prefix.Replace('description:',"description: first`ndescription:")+'Read.'; Valid=$false },
    @{ Name='wrong folder'; Text=$prefix.Replace('example-skill','other-skill')+'Read.'; Valid=$false },
    @{ Name='wrong case'; Text=$prefix.Replace('example-skill','Example-Skill')+'Read.'; Valid=$false },
    @{ Name='empty description'; Text=$prefix.Replace('Validate a fixture.',"''")+'Read.'; Valid=$false },
    @{ Name='sequence scalar'; Text=$prefix.Replace('Validate a fixture.','[one, two]')+'Read.'; Valid=$false },
    @{ Name='unclosed quote'; Text=$prefix.Replace('Validate a fixture.',"'unclosed")+'Read.'; Valid=$false },
    @{ Name='bad escape'; Text=$prefix.Replace('Validate a fixture.','"bad\q"')+'Read.'; Valid=$false },
    @{ Name='unknown metadata'; Text=$prefix.Replace('description:',"unknown: unsupported`ndescription:")+'Read.'; Valid=$false },
    @{ Name='typed infinity'; Text=$prefix.Replace('Validate a fixture.','.inf')+'Read.'; Valid=$false },
    @{ Name='typed hex'; Text=$prefix.Replace('Validate a fixture.','0x10')+'Read.'; Valid=$false },
    @{ Name='typed exponent'; Text=$prefix.Replace('Validate a fixture.','1.0e+3')+'Read.'; Valid=$false },
    @{ Name='quoted numeric text'; Text=$prefix.Replace('Validate a fixture.',"'1.0e+3'")+'Read.'; Valid=$true },
    @{ Name='duplicate fenced header'; Text=$prefix+"---`nname: wrong`n---`nRead."; Valid=$true }
)
foreach ($case in $cases) {
    $problem = Get-RedMonitorSkillProblem -FolderName 'example-skill' -Text $case.Text
    if ((-not $problem) -ne $case.Valid) { throw "Header control '$($case.Name)' expected valid=$($case.Valid): $problem" }
}
$run = Assert-RedMonitorOutputPath (Join-Path $root ('.build/agent-guidance-tests/'+[guid]::NewGuid().ToString('N')))
$packageChecks = 0
$publicChecks = 0
$skippedLinks = 0
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
function Expect([string]$Name,[bool]$Accepted,[string]$ExpectedProblem='') {
    $before = Snapshot
    $problem = $null
    try { Test-RedMonitorAgentGuidance -Root $run }
    catch [System.Management.Automation.RuntimeException] { $problem = $_.Exception.Message }
    if ((-not $problem) -ne $Accepted) { throw "Package/lifecycle control '$Name' expected accepted=$Accepted`: $problem" }
    if ($ExpectedProblem -and $problem -notlike "*$ExpectedProblem*") { throw "Control '$Name' rejected for the wrong reason: $problem" }
    if ((Snapshot) -cne $before) { throw "Validation wrote files during '$Name'." }
    Write-Host "PASS agent guidance $Name"
    $script:packageChecks++
}
$skill = '.agents/skills/example-skill/SKILL.md'
Put $skill ($prefix+'Read [contract](../../../Specs/contract.md).')
Put 'Specs/contract.md' '# Contract'
Put 'Specs/Plans/WIP/README.md' '[Active plan](Example_2026-10-28.md)'
Put 'Specs/Plans/WIP/Example_2026-10-28.md' '# Active plan'
Put 'Specs/Plans/Done/README.md' 'No completed plans.'
Expect 'active indexed plan' $true
Put 'Specs/Plans/WIP/README.md' '[plan]: Example_2026-10-28.md'
Expect 'definition alone does not index a plan' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[First][plan] [Second][plan]`n[plan]: Example_2026-10-28.md"
Expect 'two rendered reference uses are duplicate index links' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]: Example_2026-10-28.md`n[unused]: Example_2026-10-28.md"
Expect 'unused second definition is not a duplicate index link' $true
Put 'Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]: Example_2026-10-28.md"
Expect 'ordinary one-use reference indexes a plan' $true
Put 'Specs/Plans/WIP/README.md' "[plan]:`n  Example_2026-10-28.md"
Expect 'continued definition alone does not index a plan' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]:`n  Example_2026-10-28.md (Plan contract)"
Expect 'one continued reference use indexes a plan' $true
Put 'Specs/Plans/WIP/README.md' "[plan][]`n[plan]: Example_2026-10-28.md"
Expect 'one collapsed use indexes a plan' $true
Put 'Specs/Plans/WIP/README.md' "[plan]`n[plan]: Example_2026-10-28.md"
Expect 'one defined shortcut use indexes a plan' $true
Put 'Specs/Plans/WIP/README.md' "[plan] [plan]`n[plan]: Example_2026-10-28.md"
Expect 'space-separated shortcuts count two uses' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[plan]`t[plan]`n[plan]: Example_2026-10-28.md"
Expect 'tab-separated shortcuts count two uses' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[plan]`n[plan]`n[plan]: Example_2026-10-28.md"
Expect 'newline-separated shortcuts count two uses' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "[plan][plan]`n[plan]: Example_2026-10-28.md"
Expect 'adjacent equal labels form one full reference' $true
Put 'Specs/Plans/WIP/README.md' "[plan] [ordinary]`n[plan]: Example_2026-10-28.md"
Expect 'shortcut followed by unrelated bracket text remains one link' $true
Put 'Specs/Plans/WIP/README.md' "\[plan]`n[plan]: Example_2026-10-28.md"
Expect 'escaped shortcut text is not a rendered link' $false 'exactly one index link'
Put 'Specs/Plans/WIP/README.md' "\\[plan]`n[plan]: Example_2026-10-28.md"
Expect 'even backslash prefix leaves the shortcut link live' $true
Put 'Specs/Plans/WIP/README.md' "[plan](Example_2026-10-28.md)`n[plan]: Example_2026-10-28.md"
Expect 'inline use matching a reference label counts only once' $true
Put 'Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]: Example_2026-10-28.md`n[unused]: absent.md"
Expect 'unused declaration still validates its resource target' $false 'missing local reference'
Put 'Specs/Plans/WIP/README.md' '[Active plan](Example_2026-10-28.md)'
Put $skill ($prefix+'Read [contract](../../../Specs/missing.md).')
Expect 'missing contract refused' $false
Put $skill ($prefix+'Read [outside](../../../../outside.md).')
Expect 'non-repository reference refused' $false
Put $skill ($prefix+'Read [web](https://example.invalid/contract) and [section](#local).')
Expect 'external links are not fetched' $true
Put $skill ($prefix+'```markdown'+"`n[example](missing.md)`n"+'```')
Expect 'illustrative fenced link ignored' $true
Put $skill ($prefix+'Read [encoded contract](../../../Specs/contract%20name.md#section).')
Put 'Specs/contract name.md' '# Contract with space'
Expect 'encoded path and fragment' $true
Put $skill ($prefix+'Read [repository](../../..).')
Expect 'repository directory target is contained' $true
Put 'Specs/contract(v1).md' '# Parenthesized contract'
Put $skill ($prefix+'Read [contract](../../../Specs/contract(v1).md).')
Expect 'balanced destination parentheses' $true
Put $skill ($prefix+'The syntax is `[example](missing.md)` or `` `[another](absent.md)` ``.')
Expect 'inline-code pseudo-links ignored' $true
Put $skill ($prefix+'first `'+"`n`n[Missing](missing.md)`n`n"+'last `')
Expect 'inline-code delimiters do not hide another paragraph' $false 'missing local reference'
Put $skill ($prefix+'first `'+"`n `t`n[Missing](missing.md)`n`n"+'last `')
Expect 'whitespace-only blank line ends inline-code span' $false 'missing local reference'
Put $skill ($prefix+'Read `'+"soft`n[example](missing.md)"+'` within one paragraph.')
Expect 'soft-line inline-code pseudo-link remains ignored' $true
Put $skill ($prefix+'Read [contract](../../../Specs/contract.md (Owning contract)).')
Expect 'parenthesized link title accepted' $true
Put $skill ($prefix+'Read [missing](missing.md (Owning contract)).')
Expect 'parenthesized link title cannot hide missing target' $false 'missing local reference'
Put $skill ($prefix+"[owner]:`n  ../../../Specs/contract.md`nRead [contract][owner].")
Expect 'continued reference destination resolves' $true
Put $skill ($prefix+"[owner]:`n  missing.md")
Expect 'unused continued definition still validates target' $false 'missing local reference'
Put $skill ($prefix+"[owner]:`n  ../../../Specs/contract.md (Owning contract)`nRead [owner][].")
Expect 'continued definition with parenthesized title resolves' $true
foreach ($fileName in 'guide#v1.md','literal%20.md') {
    Put ('Specs/'+$fileName) '# Encoded filename contract'
    $target = Join-Path $run ('Specs/'+$fileName)
    $uri = [uri]::new('file:///'+$target.Replace('\','/').Replace('%','%25').Replace('#','%23')).AbsoluteUri
    Put $skill ($prefix+'Read [contract]('+ $uri +').')
    Expect "file URI preserves literal filename $fileName" $true
}
$hidden = Join-Path $run '.agents/skills/hidden-skill'
[void][IO.Directory]::CreateDirectory($hidden)
[IO.File]::SetAttributes($hidden,[IO.FileAttributes]::Directory -bor [IO.FileAttributes]::Hidden)
try {
    Expect 'hidden package missing entrypoint refused' $false 'missing or empty SKILL.md'
    Put '.agents/skills/hidden-skill/SKILL.md' 'malformed'
    Expect 'hidden malformed package refused' $false 'missing frontmatter delimiters'
    Put '.agents/skills/hidden-skill/SKILL.md' ($prefix.Replace('example-skill','hidden-skill')+'Read.')
    Expect 'hidden valid package checked' $true
} finally {
    [IO.File]::SetAttributes($hidden,[IO.FileAttributes]::Directory)
    [IO.File]::Delete((Join-Path $hidden 'SKILL.md'))
    [IO.Directory]::Delete($hidden)
}
Put $skill ($prefix+'Read [web](//example.invalid/no-fetch).')
Expect 'protocol-relative external URL ignored' $true
$absoluteContract = (Join-Path $run 'Specs/contract.md').Replace('\','/')
Put $skill ($prefix+"Read [contract]($absoluteContract).")
Expect 'contained absolute path checked' $true
Put $skill ($prefix+'Read [contract]('+([uri](Join-Path $run 'Specs/contract.md')).AbsoluteUri+').')
Expect 'contained file URI checked' $true
Put $skill ($prefix+'Read [missing]('+((Join-Path $run 'Specs/absent.md').Replace('\','/'))+').')
Expect 'missing absolute local path refused' $false 'missing local reference'
Put $skill ($prefix+'Read [missing]('+([uri](Join-Path $run 'Specs/absent.md')).AbsoluteUri+').')
Expect 'missing local file URI refused' $false 'missing local reference'
Put $skill ($prefix+"Read [contract][owner].`n[owner]: ../../../Specs/contract%20name.md")
Expect 'reference-style encoded destination' $true
Put $skill ($prefix+"Read [OWNER][].`n[owner]: ../../../Specs/contract(v1).md")
Expect 'collapsed case-insensitive reference' $true
Put $skill ($prefix+"Read [contract][owner].`n[owner]: ../../../Specs/absent.md")
Expect 'missing reference definition target refused' $false 'missing local reference'
Put $skill ($prefix+'Read [contract][undefined].')
Expect 'undefined reference label refused' $false 'Unresolved Markdown reference label'
Put $skill ($prefix+"Read [contract][owner].`n[owner]: ../../../Specs/contract.md`n[OWNER]: ../../../Specs/absent.md")
Expect 'first normalized reference definition wins' $true
Put $skill ($prefix+'Read [support](references/working.md).')
Put '.agents/skills/example-skill/references/working.md' 'Read [missing](absent.md).'
Expect 'missing supporting reference refused' $false
Put '.agents/skills/example-skill/references/working.md' 'Read [contract](../../../../Specs/contract.md).'
Expect 'supporting reference directory is the base' $true
Put $skill ($prefix+'Read [contract](../../../Specs/contract.md).')
Put 'Specs/Plans/WIP/README.md' '# Active work'
Expect 'unindexed WIP refused' $false
Put 'Specs/Plans/WIP/README.md' '[one](Example_2026-10-28.md) [duplicate](Example_2026-10-28.md)'
Expect 'duplicate active index entry refused' $false
Put 'Specs/Plans/WIP/README.md' '[Active plan](Example_2026-10-28.md)'
$source = [IO.Path]::GetFullPath((Join-Path $run 'Specs/Plans/WIP/Example_2026-10-28.md'))
$destination = [IO.Path]::GetFullPath((Join-Path $run 'Specs/Plans/Done/Example_2026-10-28.md'))
if (-not $source.StartsWith($run+'\',[StringComparison]::OrdinalIgnoreCase) -or
    -not $destination.StartsWith($run+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture move escaped its owned run.' }
[IO.File]::Move($source,$destination)
Expect 'stale WIP index refused after move' $false
Put 'Specs/Plans/WIP/README.md' '# Active work; none pending'
Put 'Specs/Plans/Done/README.md' '[Completed plan](Example_2026-10-28.md)'
Expect 'completed plan no longer required in WIP' $true
[void][IO.Directory]::CreateDirectory((Join-Path $run '.agents/skills/incomplete-skill'))
Expect 'missing skill entrypoint refused' $false
[IO.Directory]::Delete((Join-Path $run '.agents/skills/incomplete-skill'))
Put $skill $prefix
Expect 'empty packaged body refused' $false
Put $skill ($prefix+'Read the contract.')
Expect 'final retained fixture' $true

# Reparse controls stay entirely inside the same owned fixture. Privilege-limited hosts report a
# distinct skip instead of claiming these controls ran; other validation never needs link privileges.
$skillPath = Join-Path $run $skill
$linkedTarget = Join-Path $run 'fixtures/not-readable-as-utf8.dat'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($linkedTarget))
[IO.File]::WriteAllBytes($linkedTarget,[byte[]]@(0xff))
[IO.File]::Delete($skillPath)
$linkCreated = $false
try { [void][IO.File]::CreateSymbolicLink($skillPath,$linkedTarget); $linkCreated = $true }
catch [UnauthorizedAccessException] { $skippedLinks++; Write-Host 'SKIP file-reparse fixture: symbolic-link privilege unavailable.' }
try {
    if ($linkCreated) { Expect 'reparse SKILL rejected before strict UTF-8 decoding' $false 'reparse point' }
} finally {
    if ($linkCreated) { [IO.File]::Delete($skillPath) }
    Put $skill ($prefix+'Read the contract.')
}

# Run the actual public entrypoint against a minimal checkout-shaped fixture, not just the helper.
$public = Join-Path $run 'public-entrypoint'
Put 'public-entrypoint/validate.ps1' ([IO.File]::ReadAllText((Join-Path $root 'validate.ps1')))
Put 'public-entrypoint/Build/AgentGuidance.psm1' ([IO.File]::ReadAllText((Join-Path $root 'Build/AgentGuidance.psm1')))
foreach ($name in 'AGENTS.md','LICENSE.txt','README.md','capabilities.json','Specs/README.md','Specs/Plans/WIP/README.md',
    'Specs/Plans/Done/README.md','Specs/SourceImport/source-origin.json','Build/Toolchain.psm1','vcpkg.json') {
    Put ('public-entrypoint/'+$name) $(if ($name.EndsWith('.md')) { '# Fixture' } elseif ($name.EndsWith('.json')) { '{}' } else { '' })
}
foreach ($name in 'src/RedMonitor.vcxproj','Tests/MonitorTest.vcxproj') { Put ('public-entrypoint/'+$name) '<Project />' }
foreach ($name in 'Dependencies/DxUi.lock.json','vcpkg-tool.json') { Put ('public-entrypoint/'+$name) ('{"commit":"'+('0'*40)+'"}') }
Put 'public-entrypoint/Specs/contract name.md' '# Encoded contract'
Put 'public-entrypoint/Specs/contract(v1).md' '# Parenthesized contract'
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
$publicSkill = 'public-entrypoint/.agents/skills/example-skill/SKILL.md'
Put $publicSkill ($prefix+'Read [contract](../../../Specs/contract%20name.md).')
Expect-Public 'encoded path accepted by actual entrypoint' $true
Put $publicSkill ($prefix+'```markdown'+"`n[example](missing.md)`n"+'```')
Expect-Public 'fenced illustration accepted by actual entrypoint' $true
Put $publicSkill ($prefix+'The syntax is `[example](missing.md)`.')
Expect-Public 'inline-code pseudo-link accepted by actual entrypoint' $true
Put $publicSkill ($prefix+'Read [contract](../../../Specs/contract(v1).md).')
Expect-Public 'balanced parentheses accepted by actual entrypoint' $true
Put $publicSkill ($prefix+"Read [contract][owner].`n[owner]: ../../../Specs/contract%20name.md")
Expect-Public 'reference-style link accepted by actual entrypoint' $true
Put $publicSkill ($prefix.Replace('Validate a fixture.','"2026-10-28T09:00:00Z"')+'Read.')
Expect-Public 'quoted timestamp remains a string publicly' $true
Put $publicSkill ($prefix+'first `'+"`n`n[Missing](missing.md)`n`n"+'last `')
Expect-Public 'cross-paragraph backticks do not hide missing link publicly' $false 'missing local reference'
Put $publicSkill ($prefix+'Read [contract](../../../Specs/contract%20name.md (Owning contract)).')
Expect-Public 'parenthesized title accepted publicly' $true
Put $publicSkill ($prefix+'Read [missing](missing.md (Owning contract)).')
Expect-Public 'parenthesized title missing target refused publicly' $false 'missing local reference'
Put $publicSkill ($prefix+"[owner]:`n  ../../../Specs/contract%20name.md`nRead [contract][owner].")
Expect-Public 'continued reference accepted publicly' $true
Put $publicSkill ($prefix+"[unused]:`n  missing.md")
Expect-Public 'unused continued missing target refused publicly' $false 'missing local reference'
foreach ($fileName in 'guide#v1.md','literal%20.md') {
    Put ('public-entrypoint/Specs/'+$fileName) '# Encoded filename contract'
    $target = Join-Path $public ('Specs/'+$fileName)
    $uri = [uri]::new('file:///'+$target.Replace('\','/').Replace('%','%25').Replace('#','%23')).AbsoluteUri
    Put $publicSkill ($prefix+'Read [contract]('+ $uri +').')
    Expect-Public "file URI literal filename $fileName accepted publicly" $true
}
$publicHidden = Join-Path $public '.agents/skills/hidden-skill'
Put 'public-entrypoint/.agents/skills/hidden-skill/SKILL.md' 'malformed'
[IO.File]::SetAttributes($publicHidden,[IO.FileAttributes]::Directory -bor [IO.FileAttributes]::Hidden)
try {
    Expect-Public 'hidden malformed skill rejected publicly' $false 'missing frontmatter delimiters'
    Put 'public-entrypoint/.agents/skills/hidden-skill/SKILL.md' ($prefix.Replace('example-skill','hidden-skill')+'Read.')
    Expect-Public 'hidden valid skill checked publicly' $true
} finally {
    [IO.File]::SetAttributes($publicHidden,[IO.FileAttributes]::Directory)
    [IO.File]::Delete((Join-Path $publicHidden 'SKILL.md'))
    [IO.Directory]::Delete($publicHidden)
}
Put $publicSkill ($prefix+"Read [contract][owner].`n[owner]: ../../../Specs/absent.md")
Expect-Public 'reference definition missing local target refused publicly' $false 'missing local reference'
Put $publicSkill ($prefix+'Read the contract.')
Put 'public-entrypoint/Specs/Plans/WIP/Example_2026-10-28.md' '# Active plan'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'one rendered reference indexes a public plan' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan]:`n  Example_2026-10-28.md"
Expect-Public 'continued definition-only public index refused' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]:`n  Example_2026-10-28.md (Plan contract)"
Expect-Public 'one continued reference indexes public plan' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' '[plan]: Example_2026-10-28.md'
Expect-Public 'definition-only public index refused' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[First][plan] [Second][plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'two public uses sharing a definition refused' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[Only][plan]`n[plan]: Example_2026-10-28.md`n[unused]: Example_2026-10-28.md"
Expect-Public 'unused second public definition does not duplicate occurrence' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'defined shortcut counts in public index' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan] [plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'spaced duplicate shortcuts refused publicly' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan]`t[plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'tab-separated duplicate shortcuts refused publicly' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan]`n[plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'newline-separated duplicate shortcuts refused publicly' $false 'exactly one index link'
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan][plan]`n[plan]: Example_2026-10-28.md"
Expect-Public 'adjacent full reference still counts once publicly' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' "[plan][]`n[plan]: Example_2026-10-28.md"
Expect-Public 'collapsed reference counts in public index' $true
Put 'public-entrypoint/Specs/Plans/WIP/README.md' '[Active plan](Example_2026-10-28.md)'
Put $publicSkill ($prefix+'Read [web](//example.invalid/no-fetch).')
Expect-Public 'protocol-relative external URL does not access network' $true
Put $publicSkill ($prefix+'Read [missing]('+((Join-Path $public 'Specs/absent.md').Replace('\','/'))+').')
Expect-Public 'absolute missing local path refused by actual entrypoint' $false 'missing local reference'
Put $publicSkill ($prefix+'Read [missing]('+([uri](Join-Path $public 'Specs/absent.md')).AbsoluteUri+').')
Expect-Public 'missing file URI refused by actual entrypoint' $false 'missing local reference'
Put $publicSkill ($prefix+'Read the contract.')
if ($linkCreated) {
    $publicSkillPath = Join-Path $run $publicSkill
    [IO.File]::Delete($publicSkillPath)
    [void][IO.File]::CreateSymbolicLink($publicSkillPath,$linkedTarget)
    try { Expect-Public 'reparse SKILL refused before public readers' $false 'reparse point' }
    finally { [IO.File]::Delete($publicSkillPath); Put $publicSkill ($prefix+'Read the contract.') }
}
Write-Host "PASS $($cases.Count) header, $packageChecks package/lifecycle/read-only and $publicChecks public-entrypoint controls; symbolic-link controls skipped: $skippedLinks. Fixture: $run"
