Set-StrictMode -Version Latest

function Read-RedMonitorBenchmark {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][int] $BurstCount, [Parameter(Mandatory)][int] $PayloadChars)

    $result = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if ($result.scenario -cne 'monitor.chrome.dxui_toolbar_statusstrip' -or $result.status -cne 'passed' -or
        $result.machineHash -cnotmatch '^[0-9a-f]{12}$' -or [string]::IsNullOrWhiteSpace($result.runId)) {
        throw "The Monitor chrome fixture did not produce a valid passing receipt. $Path"
    }
    $warp = @($result.checks | Where-Object { $_.name -ceq 'color view uses WARP' -and $_.status -ceq 'passed' })
    $burst = $result.monitorEtwBurstLatency
    $scrollback = $result.monitorScrollbackSelfTest
    if ($warp.Count -ne 1 -or ($result.checks | Where-Object { $_.status -cne 'passed' }) -or
        $burst.enabled -cne $true -or $burst['count'] -ne $BurstCount -or $burst.payloadChars -ne $PayloadChars -or
        $burst.metricPresence.allPresent -cne $true -or $scrollback.enabled -cne $true -or
        $scrollback.metricPresence.allPresent -cne $true -or $result.monitorFrameMetricPresence.allPresent -cne $true -or
        $result.monitorRetainedStateMetricPresence.allPresent -cne $true) {
        throw "The receipt did not cover the fixed WARP burst and scrollback fixture. $Path"
    }

    $summaries = [ordered]@{
        'monitor.frame.append_to_visible_us' = @($burst.metricSummary)
        'monitor.etw.batch_drain_us' = @($burst.metricSummary)
        'monitor.frame.total_us' = @($burst.metricSummary)
        'monitor.frame.present_us' = @($burst.metricSummary)
        'monitor.frame.scrollback_slice_us' = @($scrollback.metricSummary)
    }
    $timing = [ordered]@{}
    foreach ($name in $summaries.Keys) {
        $found = @($summaries[$name] | Where-Object { $_.metric -ceq $name })
        $minimumCount = if ($name -ceq 'monitor.frame.scrollback_slice_us') { 1 } else { $BurstCount }
        if ($found.Count -ne 1 -or $found[0]['count'] -lt $minimumCount) {
            throw "Incomplete benchmark samples for $name. $Path"
        }
        $metric = $found[0]
        $previous = 0
        foreach ($quantile in 'p50', 'p95', 'p99', 'max') {
            $value = $metric[$quantile]
            if ($value -isnot [ValueType] -or ![double]::IsFinite($value) -or $value -lt $previous) {
                throw "Invalid benchmark quantile $quantile for $name. $Path"
            }
            $timing["$name/$quantile"] = $value
            $previous = $value
        }
    }

    return [ordered]@{
        machineHash = $result.machineHash
        runId = $result.runId
        checks = @($result.checks.name | Sort-Object -CaseSensitive)
        timingUs = $timing
    }
}

Export-ModuleMember -Function Read-RedMonitorBenchmark
