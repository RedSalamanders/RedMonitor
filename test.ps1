<#
.SYNOPSIS
Runs non-activating standalone model, file and listener-lifetime tests.
.DESCRIPTION
Builds unless SkipBuild is selected, validates the build receipt and artifact hashes, and runs owned
console processes with timeouts. Test data and source-bound receipts stay under a fresh .build/test-runs directory.
.PARAMETER Platform
x64 runtime target. ARM64 requires a native ARM64 host.
.PARAMETER Configuration
Debug, Release or ASan Debug.
.PARAMETER SkipBuild
Reuse only a source-compatible successful build receipt.
.PARAMETER IncludeLiveEtw
Require a real ETW producer/listener roundtrip; permission denial fails this requested gate.
.PARAMETER LocalSdkBuildReceipt
Original local SDK candidate build record. Runs the same Release scenarios against its complete held output;
requires LocalSdkBuildSha256, native execution and SkipBuild. Never supplies pinned PrePush/main acceptance.
.PARAMETER LocalSdkBuildSha256
Independently retained SHA-256 of the original local candidate build record.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Debug',[switch]$SkipBuild,[switch]$IncludeLiveEtw,
      [string]$LocalSdkBuildReceipt='', [string]$LocalSdkBuildSha256='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$localSdkMode=[bool]($LocalSdkBuildReceipt -or $LocalSdkBuildSha256)
if($localSdkMode -and (-not $IsWindows -or $env:GITHUB_ACTIONS -ceq 'true' -or $env:CI_NATIVE_BUILDS_DISABLED -ceq 'true')){
    throw 'Local SDK runtime requires local Windows native execution.'
}
if($localSdkMode -and (-not $LocalSdkBuildReceipt -or $LocalSdkBuildSha256 -cnotmatch '^[a-f0-9]{64}$' -or $Configuration -cne 'Release' -or -not $SkipBuild)){
    throw 'Local SDK runtime requires the original build record/digest, Release and explicit SkipBuild.'
}
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
if($Platform -eq 'ARM64' -and [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64'){
    throw 'ARM64 runtime tests require a native ARM64 host.'
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
        @{name='client-contract';exe='ClientContractTests.exe';argument=$null},
        @{name='settings-contract';exe='SettingsContractTests.exe';argument=$null})
    if($IncludeLiveEtw){$scenarios+=@{name='transport-roundtrip';exe='TransportRoundtripTests.exe';argument=$null}}
    $scenarios+=@{name='installed-production-metadata';exe='ClientContractTests.exe';argument=$null;
        arguments=@($(if($build.viewerTestsEnabled -or $Configuration -ne 'Release'){'--expect-development'}else{'--expect-production'}),(Join-Path $output 'RedMonitor.exe'))}
    $asanProbe=$Configuration -eq 'ASan Debug'
    if($asanProbe){$scenarios+=@{name='asan-detection';exe='AsanProbe.exe';argument='--detect';expectedAsan=$true}}
    foreach($entry in $scenarios){
        $scenario=$entry.name
        $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $output $entry.exe))
        if($entry.argument){$start.ArgumentList.Add($entry.argument)}
        if($entry.ContainsKey('arguments')){foreach($argument in $entry.arguments){$start.ArgumentList.Add($argument)}}
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
            $scenarioPassed=if($expectedAsan){$process.ExitCode -ne 0 -and $text -match 'AddressSanitizer: heap-buffer-overflow'}else{$process.ExitCode -eq 0}
            $rows.Add([pscustomobject][ordered]@{scenario=$scenario;exitCode=$process.ExitCode;passed=$scenarioPassed;expectedAsanDetection=[bool]$expectedAsan;elapsedMs=$timer.Elapsed.TotalMilliseconds})
            Write-Host "$scenario : exit $($process.ExitCode), passed=$scenarioPassed, $([math]::Round($timer.Elapsed.TotalMilliseconds,2)) ms"
        }finally{$process.Dispose()}
    }
}catch{$primaryFailure=$_;throw}finally{
    [Environment]::SetEnvironmentVariable('REDMONITOR_TEST_ROOT',$previousRoot,'Process')
    $closeFailure=$null
    if($null -ne $runtimeInput -and -not $runtimeInput.Closed){
        try{Close-CiLocalSdkApplicationRuntimeInput $runtimeInput}catch{$closeFailure=$_}
    }
    $expected=if($IncludeLiveEtw){7}else{6}
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
