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
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Debug',[switch]$SkipBuild)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
if($Platform -eq 'ARM64' -and [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64'){
    throw 'ARM64 runtime tests require a native ARM64 host.'
}
if(-not $SkipBuild){& (Join-Path $PSScriptRoot 'build.ps1') -Platform $Platform -Configuration $Configuration}
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
$run=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/test-runs/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $run|Out-Null
$previousRoot=[Environment]::GetEnvironmentVariable('REDMONITOR_TEST_ROOT','Process')
$rows=[Collections.Generic.List[object]]::new()
$started=[DateTime]::UtcNow
try{
    $env:REDMONITOR_TEST_ROOT=$run
    foreach($scenario in @('diagnostics-gate','scrollbar-model','document-model')){
        $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $output 'MonitorTest.exe'))
        $start.ArgumentList.Add("--$scenario-selftest")
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
            $rows.Add([ordered]@{scenario=$scenario;exitCode=$process.ExitCode;elapsedMs=$timer.Elapsed.TotalMilliseconds})
            Write-Host "$scenario : exit $($process.ExitCode), $([math]::Round($timer.Elapsed.TotalMilliseconds,2)) ms"
        }finally{$process.Dispose()}
    }
}finally{
    [Environment]::SetEnvironmentVariable('REDMONITOR_TEST_ROOT',$previousRoot,'Process')
    $passed=$rows.Count -eq 3 -and @($rows|Where-Object exitCode -ne 0).Count -eq 0 -and $identity -ceq (Get-RedMonitorSourceIdentity)
    [ordered]@{schemaVersion=1;passed=$passed;sourceIdentity=$identity;platform=$Platform;configuration=$Configuration;
        buildReceiptSha256=(Get-FileHash -LiteralPath (Join-Path $output 'build-receipt.json')).Hash;
        scenarios=@($rows.ToArray());startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');interactive=$false}|
        ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $run 'receipt.json') -Encoding utf8
    Write-Host "Evidence: $run"
}
if(-not $passed){throw 'One or more RedMonitor scenarios failed; see the retained receipt.'}
