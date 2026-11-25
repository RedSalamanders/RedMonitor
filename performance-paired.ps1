#Requires -Version 7.2
<#
.SYNOPSIS
Collect paired x64 Release WARP timing for RedMonitor's chrome, burst and scrollback fixture.
.DESCRIPTION
Freeze both sources and build them with matching pins. Retain the alternating schedule, build receipts,
raw fixture results and per-block timing differences. The product's performance review owns acceptance.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BaselineRevision,
    [string] $CandidateRevision = 'HEAD',
    [ValidateRange(5, 20)][int] $Blocks = 5,
    [ValidateRange(-1, [int]::MaxValue)][int] $Seed = -1,
    [switch] $CalibrationAA,
    [string] $OutputDirectory = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (![OperatingSystem]::IsWindows() -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'Use native x64 Windows for the paired Monitor benchmark.'
}

$root = $PSScriptRoot
$engine = Join-Path $root '.ci-engine'
Import-Module (Join-Path $engine 'Tools/Modules/Ci.Policy.psm1') -Force
Import-Module (Join-Path $engine 'Tools/Modules/Ci.Project.psm1') -Force
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $root 'Build/MonitorBenchmark.psm1') -Force
$driver = Resolve-CiCommit $root 'HEAD'
if ((git -C $root status --porcelain) -or $LASTEXITCODE) { throw 'Use a clean benchmark driver checkout.' }
$baseline = Resolve-CiCommit $root $BaselineRevision
$candidate = Resolve-CiCommit $root $CandidateRevision
if (($baseline -ceq $candidate) -ne [bool]$CalibrationAA) {
    throw 'Use distinct revisions for a comparison and one revision for CalibrationAA.'
}
$enginePin = Resolve-CiCommit $engine 'HEAD'
if ((git -C $engine status --porcelain) -or $LASTEXITCODE) { throw 'Use a clean, pinned CI engine.' }

$dependencies = [ordered]@{}
foreach ($path in 'Dependencies/DxUi.lock.json', 'vcpkg.json', 'vcpkg-tool.json') {
    $before = git -C $root rev-parse --verify "$($baseline):$path"
    if ($LASTEXITCODE) { throw "Missing baseline input $path." }
    $after = git -C $root rev-parse --verify "$($candidate):$path"
    if ($LASTEXITCODE -or $before -cne $after) { throw "The paired dependency input differs. $path" }
    $dependencies[$path] = $before
}
foreach ($revision in @($driver, $baseline, $candidate) | Select-Object -Unique) {
    $policy = git -C $root show "$($revision):.ci/project.json" | Out-String | ConvertFrom-Json
    if ($LASTEXITCODE -or $policy.repository -cne 'RedSalamanders/RedMonitor' -or $policy.engine.ref -cne $enginePin) {
        throw "The revision must use the verified engine pin. $revision"
    }
}

$buildRoot = Join-Path $root '.build'
if (!$OutputDirectory) { $OutputDirectory = Join-Path $buildRoot 'paired' }
$parent = Assert-CiContainedPath -Root $buildRoot -Path ([IO.Path]::GetFullPath($OutputDirectory, $root))
$runRoot = Assert-CiContainedPath -Root $root -Path (Join-Path $parent ([guid]::NewGuid().ToString('N').Substring(0, 12)))
if (Test-Path -LiteralPath $runRoot) { throw 'Use a fresh benchmark directory.' }
$evidence = [IO.Directory]::CreateDirectory((Join-Path $runRoot 'evidence')).FullName
$runTemp = [IO.Directory]::CreateDirectory((Join-Path $runRoot 'tmp')).FullName
$resultPath = Join-Path $evidence 'study.json'

if ($Seed -eq -1) { $Seed = [Security.Cryptography.RandomNumberGenerator]::GetInt32([int]::MaxValue) }
$random = [Random]::new($Seed)
$schedule = @(1..$Blocks | ForEach-Object { if ($random.Next(2) -eq 0) { 'ABBA' } else { 'BAAB' } })
$burstCount = 512
$payloadChars = 64
$fixtureArgs = @('--warp', '--chrome-selftest', '--monitor-scrollback-selftest', '--monitor-etw-burst-mode=latency',
    "--monitor-etw-burst-count=$burstCount", "--monitor-etw-burst-size=$payloadChars")
$report = [ordered]@{
    schemaVersion = 1
    status = 'started'
    scope = 'hidden WARP monitor fixture timing'
    driver = $driver
    engine = $enginePin
    baseline = $baseline
    candidate = $candidate
    calibrationAA = [bool]$CalibrationAA
    platform = 'x64'
    configuration = 'Release'
    arguments = $fixtureArgs
    seed = $Seed
    schedule = $schedule
    dependencies = $dependencies
    builds = [ordered]@{}
    observations = [Collections.Generic.List[object]]::new()
    pairedDifferencesUs = [Collections.Generic.List[object]]::new()
}

function Get-ReviewedBuild([string] $Tree, [string] $Source) {
    if ((Resolve-CiCommit $Tree 'HEAD') -cne $Source -or (git -C $Tree status --porcelain) -or $LASTEXITCODE) {
        throw "Expected the clean measured revision. $Source"
    }
    $profile = Join-Path $Tree '.build/x64/Release'
    $receiptPath = Join-Path $profile 'build-receipt.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $exe = Join-Path $profile 'RedMonitor.exe'
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
    $hash = (Get-FileHash -LiteralPath $exe).Hash
    $artifact = @($receipt.artifacts | Where-Object path -CEQ 'RedMonitor.exe')
    Assert-CiPeArchitecture -Path $exe -Platform x64
    if (!$receipt.passed -or $receipt.platform -cne 'x64' -or $receipt.configuration -cne 'Release' -or
        !$receipt.viewerTestsEnabled -or $receipt.productionOnly -or $receipt.dxuiRecipe.recipe -cne 'PinnedSource' -or
        $receipt.sourceIdentity -cne (Get-RedMonitorSourceIdentity -Root $Tree) -or
        $version.ProductName -cne 'RedMonitor' -or $version.FileBuildPart -ne $receipt.buildNumber -or
        $version.SpecialBuild -cne 'RedSalamander.TestSurface=ENABLE_TESTS' -or
        $artifact.Count -ne 1 -or $artifact[0].sha256 -cne $hash) {
        throw "Expected a source-bound, test-enabled Release viewer. $Source"
    }
    return [ordered]@{
        tree = $Tree
        source = $Source
        exe = $exe
        sha256 = $hash
        receipt = $receiptPath
        receiptSha256 = (Get-FileHash -LiteralPath $receiptPath).Hash
        toolchainSha256 = $receipt.toolchainSha256
    }
}

function New-BenchmarkBuild([string] $Role, [string] $Source) {
    $tree = Join-Path $runRoot $Role
    git -C $root -c core.longpaths=true worktree add --quiet --detach $tree $Source
    if ($LASTEXITCODE) { throw "Could not create the measured worktree. $Role" }
    $treeEngine = Join-Path $tree '.ci-engine'
    git -c core.longpaths=true clone --quiet --no-hardlinks --no-checkout -- $engine $treeEngine
    if ($LASTEXITCODE) { throw 'Could not provision the pinned engine.' }
    git -C $treeEngine remote set-url origin 'https://github.com/RedSalamanders/.github.git'
    if ($LASTEXITCODE) { throw 'Could not configure the pinned engine origin.' }
    git -C $treeEngine switch --quiet --detach $enginePin
    if ($LASTEXITCODE) { throw 'Could not select the pinned engine revision.' }
    $log = Join-Path $evidence "build-$Role.log"
    pwsh -NoProfile -NonInteractive -File (Join-Path $tree 'build.ps1') -Platform x64 -Configuration Release -ViewerTests true -MaxCpuCount 2 *> $log
    if ($LASTEXITCODE) { throw "The measured Release build failed. $log" }
    $verified = Get-ReviewedBuild $tree $Source
    Copy-Item -LiteralPath $verified.receipt -Destination (Join-Path $evidence "build-$Role.json")
    return $verified
}

function Invoke-BenchmarkObservation([string] $Exe, [string] $Directory) {
    if (Get-Process RedMonitor,RedSalamanderMonitor -ErrorAction SilentlyContinue) {
        throw 'Close the existing monitor before measuring the owned fixture.'
    }
    $testRuns = [IO.Directory]::CreateDirectory((Join-Path $Directory 'Specs/TestRuns')).FullName
    $info = [Diagnostics.ProcessStartInfo]::new($Exe)
    $info.UseShellExecute = $false
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.WorkingDirectory = $Directory
    $info.Environment['REDSALAMANDER_REPO_ROOT'] = $Directory
    foreach ($argument in $fixtureArgs) { $info.ArgumentList.Add($argument) }

    $instance = [Diagnostics.Process]::Start($info)
    try {
        if (!$instance.WaitForExit(180000)) {
            $instance.Kill($true)
            $instance.WaitForExit()
            throw "The owned Monitor fixture timed out. $Directory"
        }
        if ($instance.ExitCode) { throw "Monitor fixture exited $($instance.ExitCode). $Directory" }
    } finally {
        $instance.Dispose()
    }
    $receipts = @(Get-ChildItem -LiteralPath $testRuns -Recurse -File -Filter results.json)
    if ($receipts.Count -ne 1) { throw "Expected one Monitor fixture receipt. $Directory" }
    $metrics = Join-Path $receipts[0].DirectoryName 'perf_metrics.jsonl'
    if ((Get-Item -LiteralPath $metrics).Length -eq 0) { throw "Raw Monitor metrics are missing. $Directory" }
    $record = Read-RedMonitorBenchmark -Path $receipts[0].FullName -BurstCount $burstCount -PayloadChars $payloadChars
    $record.result = [IO.Path]::GetRelativePath($evidence, $receipts[0].FullName)
    return $record
}

$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousBinarySources = $env:VCPKG_BINARY_SOURCES
try {
    $env:TEMP = $env:TMP = $runTemp
    $env:VCPKG_BINARY_SOURCES = 'clear'
    $report.builds.A = New-BenchmarkBuild A $baseline
    $report.builds.B = if ($CalibrationAA) { $report.builds.A } else { New-BenchmarkBuild B $candidate }
    if ($report.builds.A.toolchainSha256 -cne $report.builds.B.toolchainSha256) { throw 'MSBuild differed across the pair.' }
    $environment = $null
    for ($block = 0; $block -lt $schedule.Count; ++$block) {
        $replicates = @{ A = [Collections.Generic.List[object]]::new(); B = [Collections.Generic.List[object]]::new() }
        for ($position = 0; $position -lt 4; ++$position) {
            $role = [string]$schedule[$block][$position]
            $directory = Join-Path $evidence "block-$($block + 1)-$($position + 1)-$role"
            $measured = Invoke-BenchmarkObservation $report.builds[$role].exe $directory
            $signature = (@($measured.machineHash) + $measured.checks) -join [char]0
            if ($null -eq $environment) { $environment = $signature }
            if ($signature -cne $environment) { throw "The machine or fixture check inventory changed. $directory" }
            $report.observations.Add([ordered]@{block = $block + 1; position = $position + 1; role = $role; fixture = $measured})
            $replicates[$role].Add($measured.timingUs)
        }
        foreach ($metric in $replicates.A[0].Keys) {
            $meanA = ($replicates.A[0][$metric] + $replicates.A[1][$metric]) / 2
            $meanB = ($replicates.B[0][$metric] + $replicates.B[1][$metric]) / 2
            $report.pairedDifferencesUs.Add([ordered]@{
                block = $block + 1
                metric = $metric
                baseline = $meanA
                candidate = $meanB
                candidateMinusBaseline = $meanB - $meanA
            })
        }
    }
    foreach ($side in $report.builds.Values) {
        $after = Get-ReviewedBuild $side.tree $side.source
        if ($after.sha256 -cne $side.sha256 -or $after.receiptSha256 -cne $side.receiptSha256) {
            throw "A measured build changed during the study. $($side.source)"
        }
    }
    $report.status = 'collected'
    Write-Host "Paired RedMonitor evidence written to $resultPath"
} catch {
    $report.status = 'failed'
    $report.error = $_.Exception.Message
    throw
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:VCPKG_BINARY_SOURCES = $previousBinarySources
    $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resultPath -Encoding utf8NoBOM
}
