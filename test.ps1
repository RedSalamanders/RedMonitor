<#
.SYNOPSIS
Runs the RedMonitor tests affected by the checkout or the complete requested profile.
.DESCRIPTION
Calls Test-Changes.ps1 for ordinary and Full runs. Explicit suites, live ETW and local SDK requests
use the direct runner. The direct runner validates receipts and artifact hashes and runs owned console
processes with timeouts. Probe dumps stay in .build/crash-probe-artifacts outside CI artifact uploads.
.PARAMETER Platform
x64 runtime target. ARM64 requires a native ARM64 host.
.PARAMETER Configuration
Debug, Release or ASan Debug.
.PARAMETER SkipBuild
Reuse only a source-compatible successful build receipt.
.PARAMETER Full
Run every scope for the selected platform and configuration, including applicable independent checks.
.PARAMETER IncludeLiveEtw
Require a real ETW producer/listener roundtrip for a direct invocation; permission denial fails this requested gate.
.PARAMETER Suites
Shared runner suites: Regression, LiveEtw and ContainedInstallation. LiveEtw includes the regression prerequisite.
ContainedInstallation is available in Release.
.PARAMETER SkipTooling
Run direct native tests after independent validation. The shared runner passes this switch for scoped native calls.
.PARAMETER ParallelSuites
Upper limit for concurrent suites. RedMonitor runs its dependent native and installation gates serially.
.PARAMETER LocalSdkBuildReceipt
Original local SDK candidate build record. Runs the same Release scenarios against its complete held output;
requires LocalSdkBuildSha256, native execution and SkipBuild. Never supplies pinned PrePush/main acceptance.
.PARAMETER LocalSdkBuildSha256
Independently retained SHA-256 of the original local candidate build record.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Debug',[switch]$SkipBuild,[switch]$IncludeLiveEtw,
      [string]$LocalSdkBuildReceipt='', [string]$LocalSdkBuildSha256='',
      [string[]]$Suites=@(), [switch]$SkipTooling, [ValidateRange(1,8)][int]$ParallelSuites=1, [switch]$Full)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$profileOptions = @('Platform', 'Configuration', 'SkipBuild', 'ParallelSuites', 'Full')
$directOptions = @($PSBoundParameters.Keys | Where-Object { $_ -notin $profileOptions })
if ($Full -and $directOptions.Count) { throw 'Use -Full with profile options. For a specific check, use the direct test options.' }
if (-not $directOptions.Count) {
    $mode = if ($Full) { 'Full' } else { 'Affected' }
    $global:LASTEXITCODE = 0
    & (Join-Path $PSScriptRoot 'Test-Changes.ps1') -Mode $mode -Platform $Platform -Configuration $Configuration -SkipBuild:$SkipBuild -ParallelSuites $ParallelSuites
    exit $LASTEXITCODE
}
$localSdkMode=[bool]($LocalSdkBuildReceipt -or $LocalSdkBuildSha256)
if($localSdkMode -and (-not $IsWindows -or $env:GITHUB_ACTIONS -ceq 'true' -or $env:CI_NATIVE_BUILDS_DISABLED -ceq 'true')){
    throw 'Local SDK runtime requires local Windows native execution.'
}
if($localSdkMode -and (-not $LocalSdkBuildReceipt -or $LocalSdkBuildSha256 -cnotmatch '^[a-f0-9]{64}$' -or $Configuration -cne 'Release' -or -not $SkipBuild)){
    throw 'Local SDK runtime requires the original build record/digest, Release and explicit SkipBuild.'
}
$scoped = $PSBoundParameters.ContainsKey('Suites')
if ($scoped -and ($localSdkMode -or $IncludeLiveEtw)) {
    throw 'Use scoped suite names separately from the direct live ETW and local SDK options.'
}
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Build/ScopedTesting.psm1') -Scope Local
Assert-ScopedRuntimePlatform -Platform $Platform
$profileLease = if (-not $localSdkMode) {
    Enter-ScopedProfileLease -Root $PSScriptRoot -Platform $Platform -Configuration $Configuration
}
try {
if (-not $localSdkMode) {
    $reports = Get-ScopedReportRoot -Root $PSScriptRoot -Platform $Platform -Configuration $Configuration
    Remove-ScopedIteration -Root $PSScriptRoot -Path (Join-Path $reports 'iteration.json')
}
if ($scoped) {
    $manifest = Read-ScopedTestManifest -Root $PSScriptRoot -SkipProjectRules
    $names = @($Suites | ForEach-Object { $_ -split ',' })
    if (-not $names.Count -or @($names | Where-Object { -not $_ }).Count) {
        throw 'Provide at least one native suite name.'
    }
    $plan = Get-ScopedTestPlan -Manifest $manifest -Scopes $names -Configuration $Configuration
    $native = @($manifest.scopes | Where-Object { $_.native -and $_.name -cin $plan.scopes } | ForEach-Object name)
    if ($native.Count -ne $plan.scopes.Count) { throw 'test.ps1 accepts native scopes only.' }
    if (-not $SkipBuild) {
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot 'build.ps1') -Platform $Platform -Configuration $Configuration
        if ($LASTEXITCODE) { throw "Native build exited with code $LASTEXITCODE." }
    }
    $sourceIdentity = Get-RedMonitorSourceIdentity
    Import-Module (Join-Path $PSScriptRoot 'Build/TestRunEvidence.psm1') -Scope Local
    $evidence = Start-TestRunEvidence -Repository $PSScriptRoot -Context @{
        project='RedMonitor'; platform=$Platform; configuration=$Configuration; suites=$native; sourceIdentity=$sourceIdentity
    }
    $scopedFailure = $null
    $scopedPassed = $false
    try {
        if ('Regression' -in $native -or 'LiveEtw' -in $native) {
            $global:LASTEXITCODE = 0
            & $PSCommandPath -Platform $Platform -Configuration $Configuration -SkipBuild -IncludeLiveEtw:('LiveEtw' -in $native)
            if ($LASTEXITCODE) { throw "Regression or live ETW exited with code $LASTEXITCODE." }
        }
        if ('ContainedInstallation' -in $native) {
            $global:LASTEXITCODE = 0
            $package = & (Join-Path $PSScriptRoot 'package.ps1') -Platform $Platform -Configuration $Configuration -PassThru
            if ($LASTEXITCODE -or -not $package) { throw "Packaging failed (exit $LASTEXITCODE)." }
            & (Join-Path $PSScriptRoot 'Tests/Tooling.Tests.Installation.ps1') -PackageDirectory $package.extracted
            if ($LASTEXITCODE) { throw "Contained installation exited with code $LASTEXITCODE." }
        }
        if ((Get-RedMonitorSourceIdentity) -cne $sourceIdentity) { throw 'Inputs changed during scoped runtime. No scoped success was published.' }
        foreach ($suite in $native) {
            Publish-TestRunEvidenceReceipt -Run $evidence -Name "$suite-$Platform-$Configuration.json" -Receipt ([ordered]@{
                suite=$suite; platform=$Platform; configuration=$Configuration; exitCode=0; skips=@();
                sourceIdentity=$sourceIdentity; evidenceRun=$evidence.Directory
            })
        }
        $scopedPassed = $true
    } catch { $scopedFailure=$_; throw }
    finally {
        Complete-TestRunEvidenceAfterFailure -Run $evidence -Passed $scopedPassed -PrimaryFailure $scopedFailure
    }
    return
}
if(-not $SkipBuild){& (Join-Path $PSScriptRoot 'build.ps1') -Platform $Platform -Configuration $Configuration}
$lease=$null;$runtimeInput=$null
try {
if($localSdkMode){
    Import-Module (Join-Path $PSScriptRoot '.ci-engine/Tools/Modules/Ci.LocalSdkRuntime.psm1')
    $runtimeInput=Open-CiLocalSdkApplicationRuntimeInput -ProjectRoot $PSScriptRoot -BuildReceipt $LocalSdkBuildReceipt -ExpectedBuildSha256 $LocalSdkBuildSha256 -MSBuildPath (Get-RedMonitorMSBuild)
    if($runtimeInput.Build.platform -cne $Platform){throw 'Local SDK runtime platform differs from the requested native target.'}
    $output=$runtimeInput.Build.runtimeRoot
    $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($runtimeInput.Build.executable)
    if($version.SpecialBuild -cne 'RedSalamander.TestSurface=ENABLE_TESTS'){throw 'Local SDK runtime requires the actual test-enabled viewer.'}
    $identity=Get-RedMonitorSourceIdentity
    $build=[pscustomobject]@{viewerTestsEnabled=$true}
    $buildReceiptHash=$LocalSdkBuildSha256
}else{
$lease=Enter-RedMonitorOperation "artifact-$Platform-$Configuration"
$output=Join-Path $PSScriptRoot ".build/$Platform/$Configuration"
$build=Get-Content -LiteralPath (Join-Path $output 'build-receipt.json') -Raw|ConvertFrom-Json
$identity=Get-RedMonitorSourceIdentity
if(-not $build.passed -or $build.sourceIdentity -cne $identity -or $build.platform -cne $Platform -or $build.configuration -cne $Configuration){
    throw 'No matching successful source/profile build receipt. Build before testing.'
}
foreach($artifact in $build.artifacts){
    $path=Assert-RedMonitorOutputPath (Join-Path $output $artifact.path)
    if((Get-FileHash -LiteralPath $path).Hash -cne $artifact.sha256){throw "Artifact changed: $path"}
}
$buildReceiptHash=(Get-FileHash -LiteralPath (Join-Path $output 'build-receipt.json')).Hash
}
$runBase=if($localSdkMode){'.build/local-sdk-test-runs/'}else{'.build/test-runs/'}
$run=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ($runBase+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $run|Out-Null
$previousRoot=[Environment]::GetEnvironmentVariable('REDMONITOR_TEST_ROOT','Process')
$rows=[Collections.Generic.List[object]]::new()
$started=[DateTime]::UtcNow
$primaryFailure=$null
try{
    $env:REDMONITOR_TEST_ROOT=$run
    $scenarios=@(
        @{name='diagnostics-gate';exe='MonitorTest.exe';argument='--diagnostics-gate-selftest'},
        @{name='scrollbar-model';exe='MonitorTest.exe';argument='--scrollbar-model-selftest'},
        @{name='document-model';exe='MonitorTest.exe';argument='--document-model-selftest'},
        @{name='local-crash-store';exe='MonitorTest.exe';argument='--crash-store-selftest'},
        @{name='client-contract';exe='ClientContractTests.exe';argument=$null},
        @{name='settings-contract';exe='SettingsContractTests.exe';argument=$null})
    if($IncludeLiveEtw){$scenarios+=@{name='transport-roundtrip';exe='TransportRoundtripTests.exe';argument=$null}}
    $scenarios+=@{name='installed-production-metadata';exe='ClientContractTests.exe';argument=$null;
        arguments=@($(if($build.viewerTestsEnabled -or $Configuration -ne 'Release'){'--expect-development'}else{'--expect-production'}),(Join-Path $output 'RedMonitor.exe'))}
    $asanProbe=$Configuration -eq 'ASan Debug'
    $markerHashes=@{}
    if($build.viewerTestsEnabled){
        $crashArtifactRoot=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/crash-probe-artifacts/'+(Split-Path -Leaf $run)))
        New-Item -ItemType Directory -Path $crashArtifactRoot|Out-Null
        $crashExit=if($asanProbe){0xE0524DFF}else{0xC0000005}
        $scenarios+=@(
            @{name='crash-probe-main';exe='RedMonitor.exe';argument='--crash-probe';crashRoot='main';expectedExit=$crashExit},
            @{name='crash-probe-worker';exe='RedMonitor.exe';argument='--crash-probe-worker';crashRoot='worker';expectedExit=$crashExit},
            @{name='headless-crash-markers';exe='RedMonitor.exe';argument='--runtime-contract';preserveMarkers=$true})
    }
    if($asanProbe){$scenarios+=@{name='asan-detection';exe='AsanProbe.exe';argument='--detect';expectedAsan=$true}}
    foreach($entry in $scenarios){
        $scenario=$entry.name
        $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $output $entry.exe))
        if($entry.argument){$start.ArgumentList.Add($entry.argument)}
        if($entry.ContainsKey('arguments')){foreach($argument in $entry.arguments){$start.ArgumentList.Add($argument)}}
        if($entry.ContainsKey('crashRoot') -or $entry.ContainsKey('preserveMarkers')){
            $start.Environment['REDMONITOR_TEST_ROOT']=$crashArtifactRoot
        }
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $process=[Diagnostics.Process]::new();$process.StartInfo=$start
        $timer=[Diagnostics.Stopwatch]::StartNew()
        try{
            if(-not $process.Start()){throw "Could not start $scenario"}
            $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
            if(-not $process.WaitForExit(180000)){$process.Kill($true);$process.WaitForExit();throw "Owned test process timed out: $scenario"}
            $text=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $run "$scenario.log"),$text)
            $expectedAsan=$entry.ContainsKey('expectedAsan') -and $entry.expectedAsan
            $expectedExit=if($entry.ContainsKey('expectedExit')){$entry.expectedExit}else{0}
            $scenarioPassed=if($expectedAsan){$process.ExitCode -ne 0 -and $text -match 'AddressSanitizer: heap-buffer-overflow'}else{$process.ExitCode -eq $expectedExit}
            $row=[ordered]@{scenario=$scenario;exitCode=$process.ExitCode;passed=$scenarioPassed;expectedAsanDetection=[bool]$expectedAsan;elapsedMs=$timer.Elapsed.TotalMilliseconds}
            if($entry.ContainsKey('crashRoot')){
                $directory=Assert-RedMonitorOutputPath (Join-Path $crashArtifactRoot "crash-probes/$($entry.crashRoot)")
                $marker=Join-Path $directory 'pending.txt'
                $dumps=@(Get-ChildItem -LiteralPath $directory -File -Filter 'RedMonitor-report-*.dmp' -ErrorAction SilentlyContinue)
                $row.passed=$row.passed -and $dumps.Count -eq 1 -and (Test-Path -LiteralPath $marker -PathType Leaf)
                if($row.passed){
                    $stream=[IO.File]::OpenRead($dumps[0].FullName)
                    try{
                        $signature=[byte[]]::new(4)
                        $row.passed=$stream.Read($signature,0,4) -eq 4 -and [Text.Encoding]::ASCII.GetString($signature) -ceq 'MDMP'
                    }finally{$stream.Dispose()}
                    $row.passed=$row.passed -and [IO.File]::ReadAllText($marker,[Text.Encoding]::Unicode) -ceq $dumps[0].Name
                    $row.dumpSha256=(Get-FileHash -LiteralPath $dumps[0].FullName).Hash
                    $markerHashes[$marker]=(Get-FileHash -LiteralPath $marker).Hash
                }
            }
            if($entry.ContainsKey('preserveMarkers')){
                $row.passed=$row.passed -and $markerHashes.Count -eq 2
                foreach($marker in $markerHashes.Keys){
                    $row.passed=$row.passed -and (Test-Path -LiteralPath $marker -PathType Leaf) -and
                        (Get-FileHash -LiteralPath $marker).Hash -ceq $markerHashes[$marker]
                }
            }
            $rows.Add([pscustomobject]$row)
            Write-Host "$scenario : exit $($process.ExitCode), passed=$($row.passed), $([math]::Round($timer.Elapsed.TotalMilliseconds,2)) ms"
        }finally{$process.Dispose()}
    }
}catch{$primaryFailure=$_;throw}finally{
    [Environment]::SetEnvironmentVariable('REDMONITOR_TEST_ROOT',$previousRoot,'Process')
    $closeFailure=$null
    if($null -ne $runtimeInput -and -not $runtimeInput.Closed){
        try{Close-CiLocalSdkApplicationRuntimeInput $runtimeInput}catch{$closeFailure=$_}
    }
    $expected=if($IncludeLiveEtw){8}else{7}
    if($build.viewerTestsEnabled){$expected+=3}
    if($Configuration -eq 'ASan Debug'){$expected++}
    $passed=$null -eq $primaryFailure -and $null -eq $closeFailure -and $rows.Count -eq $expected -and @($rows|Where-Object passed -eq $false).Count -eq 0 -and $identity -ceq (Get-RedMonitorSourceIdentity)
    $record=[ordered]@{schemaVersion=1;passed=$passed;sourceIdentity=$identity;platform=$Platform;configuration=$Configuration;
        buildReceiptSha256=$buildReceiptHash;
        scenarios=@($rows.ToArray());liveEtwRequested=[bool]$IncludeLiveEtw;startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');interactive=$false}
    if($localSdkMode){
        $record.role='LocalUnpinnedApplicationRuntimeResult';$record.recipe='LocalUnpinnedReleaseSdk'
        $record.sourceBytes=$runtimeInput.Build.sourceBytes;$record.engineInputs=$runtimeInput.Build.engineInputs
        $record.dependency=$runtimeInput.Build.dependency;$record.runtimeBytesDigest=$runtimeInput.Build.runtimeBytes.digest
        $record.testsExecuted=$rows.Count -gt 0;$record.repositoryQualified=$false;$record.productionQualified=$false
        if($closeFailure){$record.closeError=$closeFailure.Exception.Message}
        if($primaryFailure){$record.error=$primaryFailure.Exception.Message}
    }
    $record|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $run 'receipt.json') -Encoding utf8
    Write-Host "Evidence: $run"
    if($closeFailure){if($null -eq $primaryFailure){throw $closeFailure}else{Write-Warning ('Runtime close also failed: '+$closeFailure.Exception.Message)}}
}
if(-not $passed){throw 'One or more RedMonitor scenarios failed; see the retained receipt.'}
} finally {
    if($null -ne $runtimeInput -and -not $runtimeInput.Closed){Close-CiLocalSdkApplicationRuntimeInput $runtimeInput}
    if($null -ne $lease){$lease.ReleaseMutex();$lease.Dispose()}
}
} finally { Exit-ScopedProfileLease $profileLease }
