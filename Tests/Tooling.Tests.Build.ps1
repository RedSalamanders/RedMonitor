<#
.SYNOPSIS
Checks source receipt identity and terminal build output with owned fixtures, without native compilation.
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $root 'Build/BuildPresentation.psm1') -Force
Import-Module (Join-Path $root 'Build/BuildConsole.psm1') -Force
$run=Assert-RedMonitorOutputPath (Join-Path $root ('.build/build-tooling-tests/'+[guid]::NewGuid().ToString('N')))
$fixture=Join-Path $run 'source fixture'
[void][IO.Directory]::CreateDirectory($fixture)
$checks=0
function Require([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    $script:checks++
}
function Refuses([scriptblock]$Body,[string]$Pattern){
    $failed=$false
    try{& $Body}catch{if($_.Exception.Message -notmatch $Pattern){throw};$failed=$true}
    Require $failed "Expected refusal: $Pattern"
}
function Put([string]$Name,[string]$Text){
    $path=Join-Path $fixture $Name
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path,$Text,[Text.UTF8Encoding]::new($false))
}
function Git([string[]]$CommandArguments){
    & git.exe -c core.autocrlf=false -C $fixture @CommandArguments
    if($LASTEXITCODE -ne 0){throw "Fixture Git failed: $($CommandArguments -join ' ')"}
}
function Identity {Get-RedMonitorSourceIdentity -Root $fixture}
Git @('init','--quiet')
Put '.gitignore' ".build/`n.ci-engine/`n.vs/`n*.user`n"
Put 'src/tracked.cpp' 'int fixture = 1;'
Put 'src/café 日本語.cpp' 'int unicode = 1;'
Put "src/a's [fixture].cpp" 'int special = 1;'
Git @('add','--','.gitignore','src')
$baseline=Identity
Require ($baseline -cmatch '^[0-9a-f]{64}$') 'Source identity is not SHA-256.'
$snapshot=Get-RedMonitorSourceSnapshot -Root $fixture
Require ($snapshot.Files.ContainsKey('src/café 日本語.cpp') -and $snapshot.Files.ContainsKey("src/a's [fixture].cpp")) 'Git inventory damaged Unicode or special filenames.'

# Exact reproduction of the reported false failure: only an ignored checkout's Git metadata changes.
Put '.ci-engine/.git/FETCH_HEAD' 'before fetch'
Put '.build/x64/Release/build.log' 'generated log'
Put '.vs/project/cache.bin' 'IDE cache'
Put 'src/RedMonitor.vcxproj.user' 'local IDE state'
Put '.git/FETCH_HEAD' 'repository administration'
Require ((Identity) -ceq $baseline) 'Ignored output or Git administration entered source identity.'
Put '.ci-engine/.git/FETCH_HEAD' 'after fetch'
Put '.ci-engine/Tools/Generated.ps1' 'generated checkout content'
Require ((Identity) -ceq $baseline) 'CI checkout churn caused a false source change.'
Put '.build/x64/Release/build.log' 'updated build output'
Require ((Identity) -ceq $baseline) 'Build output invalidated its own receipt.'
$tracked=Join-Path $fixture 'src/tracked.cpp'
$timestamp=[IO.File]::GetLastWriteTimeUtc($tracked)
[IO.File]::SetLastWriteTimeUtc($tracked,$timestamp.AddMinutes(-1))
Require ((Identity) -ceq $baseline) 'Timestamp-only changes invalidated source bytes.'
Put 'src/tracked.cpp' 'int fixture = 2;'
[IO.File]::SetLastWriteTimeUtc($tracked,$timestamp)
Require ((Identity) -cne $baseline) 'Same-size tracked edits with preserved timestamps were missed.'
Git @('add','--','src/tracked.cpp')
Require ((Identity) -cne $baseline) 'Staging a changed file hid its changed bytes.'
Put 'src/tracked.cpp' 'int fixture = 1;'
Git @('add','--','src/tracked.cpp')
Require ((Identity) -ceq $baseline) 'Restored source bytes did not restore identity.'
Remove-Item -LiteralPath $tracked
$deleted=Get-RedMonitorSourceSnapshot -Root $fixture
Require ($deleted.Identity -cne $baseline -and $deleted.Files['src/tracked.cpp'] -ceq '(missing)') 'Tracked deletion lost its explicit identity marker.'
Git @('add','-u','--','src/tracked.cpp')
Require ((Identity) -cne $baseline) 'Staged deletion was missed.'
Put 'src/tracked.cpp' 'int fixture = 1;'
Git @('add','--','src/tracked.cpp')
Put 'src/untracked.cpp' 'int new_source = 1;'
$added=Identity
Require ($added -cne $baseline) 'Untracked source addition was missed.'
Put 'src/untracked.cpp' 'int new_source = 2;'
Require ((Identity) -cne $added) 'Untracked source edit was missed.'
$edited=Identity
Move-Item -LiteralPath (Join-Path $fixture 'src/untracked.cpp') -Destination (Join-Path $fixture 'src/renamed.cpp')
Require ((Identity) -cne $edited) 'A source rename with unchanged bytes was missed.'
Remove-Item -LiteralPath (Join-Path $fixture 'src/renamed.cpp')
Require ((Identity) -ceq $baseline) 'Removing untracked source did not restore identity.'
Put '.build/tracked-input.h' 'Tracked inputs stay authoritative even under an ignored directory.'
Git @('add','--force','--','.build/tracked-input.h')
$trackedIgnored=Identity
Require ($trackedIgnored -cne $baseline) 'Tracked ignored input was excluded.'
Put '.build/tracked-input.h' 'Changed tracked input.'
Require ((Identity) -cne $trackedIgnored) 'Changed tracked ignored input was missed.'
$before=Identity
Push-Location $run
try{Require ((Identity) -ceq $before) 'Source identity depended on the caller directory.'}finally{Pop-Location}
Refuses {Get-RedMonitorSourceIdentity -Root $run} 'requires a Git checkout'
$invalid=Join-Path $run 'invalid checkout'
[void][IO.Directory]::CreateDirectory((Join-Path $invalid '.git'))
Refuses {Get-RedMonitorSourceIdentity -Root $invalid} 'Git source inventory'

$banner=@(Write-RedMonitorBuildBanner -Platform x64 -Configuration Release -ColorMode Always 6>&1)
$plain=@(Write-RedMonitorBuildBanner -Platform x64 -Configuration Release -ColorMode Never 6>&1)
$bannerText=@($banner|ForEach-Object{[string]$_.MessageData}) -join "`n"
$plainText=@($plain|ForEach-Object{[string]$_.MessageData}) -join "`n"
Require ($bannerText -ceq $plainText) 'Plain and colored banners have different content.'
Require ($plainText -notmatch '[^\x09\x0a\x0d\x20-\x7e]') 'ASCII banner contains non-ASCII output or terminal escapes.'
Require ($plainText -like '*Target: RedMonitor | x64 | Release | viewer + satellites + console tests*' -and
         $plainText -like '*TRACE > CAPTURE > VIEW*') 'Banner omitted its target profile or artwork.'
Require (@($banner|Where-Object{[string]$_.MessageData.ForegroundColor -eq 'Red'}).Count -gt 0 -and
         @($banner|Where-Object{[string]$_.MessageData.ForegroundColor -eq 'Cyan'}).Count -gt 0) 'Forced color lost its palette.'
$previousNoColor=[Environment]::GetEnvironmentVariable('NO_COLOR','Process')
try{
    $env:NO_COLOR='1'
    $noColor=@(Write-RedMonitorBuildBanner -Platform ARM64 -Configuration 'ASan Debug' -ProductionOnly -ColorMode Auto 6>&1)
    Require (@($noColor|Where-Object{[string]$_.MessageData.ForegroundColor -in 'Red','Cyan','Yellow','Green'}).Count -eq 0) 'NO_COLOR was ignored.'
    Require ((@($noColor|ForEach-Object{[string]$_.MessageData}) -join "`n") -like '*ARM64 | ASan Debug | viewer + satellites (production)*') 'Banner ignored the requested target set.'
}finally{[Environment]::SetEnvironmentVariable('NO_COLOR',$previousNoColor,'Process')}

$log=Join-Path $run 'build.log'
[IO.File]::WriteAllText($log,'Build succeeded. 0 Warning(s) 0 Error(s)')
Assert-NativeBuildDiagnostics -LogPath $log
foreach($diagnostic in @(
    'source.cpp(4): warning C4100: unused parameter',
    '2>C:\work\source.cpp(4): warning C4365: sign conversion',
    'LINK : warning LNK4099: missing PDB',
    'cl : Command line warning D9025 : overriding option',
    'project.targets(8,3): warning MSB1234: build diagnostic',
    'warning : custom build diagnostic',
    'file.cpp(1): fatal error C1083: missing header'
)){
    $badLog=Join-Path $run 'diagnostic.log'
    [IO.File]::WriteAllText($badLog,$diagnostic)
    Refuses {Assert-NativeBuildDiagnostics -LogPath $badLog} 'Zero-warning'
}
$binary=Join-Path $run "synthetic # app's É.exe"
[IO.File]::WriteAllText($binary,'A synthetic artifact, never executed.')
Require ((ConvertTo-NativeBuildLink -LiteralPath $binary -HyperlinkMode Never) -ceq $binary) 'Plain artifact path changed.'
$link=ConvertTo-NativeBuildLink -LiteralPath $binary -HyperlinkMode Always
Require ($link.Contains('file://localhost/') -and $link.Contains('%20') -and $link.Contains('%23')) 'Terminal link was not local and URI escaped.'
Refuses {ConvertTo-NativeBuildLink -LiteralPath ('unsafe'+[char]27+'path') -HyperlinkMode Always} 'control characters'
$result=@(Write-NativeBuildResult -Project RedMonitor -Platform x64 -Configuration Release -LogPath $log -Artifacts @($binary) -Executable $binary -ColorMode Always -HyperlinkMode Never 6>&1)
$messages=@($result|ForEach-Object{[string]$_.MessageData})
Require (@($messages|Where-Object{$_ -like 'BUILD SUCCEEDED:*'}).Count -eq 1) 'Success summary was not emitted exactly once.'
Require (@($messages|Where-Object{$_ -like "& *''*"}).Count -eq 1) 'Launch fallback did not escape its apostrophe.'
Require (@($result|Where-Object{[string]$_.MessageData.ForegroundColor -ne 'Green'}).Count -eq 0) 'Successful summary was not green.'
Refuses {Write-NativeBuildResult -Project RedMonitor -Platform x64 -Configuration Release -LogPath $badLog -Artifacts @($binary)} 'Zero-warning'
Refuses {Write-NativeBuildResult -Project RedMonitor -Platform x64 -Configuration Release -LogPath $log -Artifacts @((Join-Path $run 'absent.exe'))} 'missing'
Write-Host "PASS $checks source-identity and build-console controls: $run"
