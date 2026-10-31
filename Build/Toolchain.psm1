Set-StrictMode -Version Latest

function Get-RedMonitorMSBuild {
    Import-Module (Join-Path $PSScriptRoot '../Tools/VisualStudio.psm1') -Force
    $installation = Get-RedMonitorVisualStudioInstallation
    $relative = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') {
        'MSBuild/Current/Bin/arm64/MSBuild.exe'
    } else { 'MSBuild/Current/Bin/MSBuild.exe' }
    $path = Join-Path $installation $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "MSBuild missing: $path" }
    return $path
}

function Assert-RedMonitorOutputPath {
    param([Parameter(Mandatory)][string] $Path)
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.build')).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Output must be strictly beneath '$root': $Path"
    }
    $current = [IO.DirectoryInfo]::new($resolved)
    while ($current) {
        if ($current.Exists -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Output path contains a reparse point: $($current.FullName)"
        }
        $current = $current.Parent
    }
    return $resolved
}

function Assert-RedMonitorOutputNotRunning {
    param([Parameter(Mandatory)][string] $OutputDirectory)
    $root = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\') + '\'
    foreach ($process in @(Get-Process -Name RedMonitor,RedSalamanderMonitor,MonitorTest -ErrorAction SilentlyContinue)) {
        if ($process.Path -and $process.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Close the independently running process $($process.Id) at '$($process.Path)' before building."
        }
    }
}

function Get-RedMonitorSourceSnapshot {
    [CmdletBinding()]
    param([string]$Root = (Join-Path $PSScriptRoot '..'))
    $Root = [IO.Path]::GetFullPath($Root)
    if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        throw "Source identity requires a Git checkout at '$Root'."
    }
    Import-Module (Join-Path $PSScriptRoot 'AgentGuidance.psm1') -ErrorAction Stop
    Assert-RedMonitorOrdinaryGuidancePath $Root

    # Bind tracked and non-ignored untracked bytes, never generated checkouts or Git metadata.
    # NUL-delimited UTF-8 preserves spaces, apostrophes and non-ASCII paths independently of the console.
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($argument in @('-C',$Root,'ls-files','--cached','--others','--exclude-standard','-z')) {
        $start.ArgumentList.Add($argument)
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Git source inventory timed out after 60 seconds.'
        }
        if ($process.ExitCode -ne 0) {
            throw "Git source inventory failed ($($process.ExitCode)): $($stderr.GetAwaiter().GetResult().Trim())"
        }
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($path in $stdout.GetAwaiter().GetResult().Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
            [void]$paths.Add($path)
        }
    } finally { $process.Dispose() }
    if (-not $paths.Count) { throw 'Git source inventory is empty; no source identity can be published.' }
    $orderedPaths = [string[]]@($paths)
    [Array]::Sort($orderedPaths, [StringComparer]::Ordinal)
    $files = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $text = [Text.StringBuilder]::new("RedMonitorSource/v2`0")
    foreach ($path in $orderedPaths) {
        if ($path -match '(^/|(^|/)\.\.(/|$)|:|\\)') { throw "Invalid Git source path: $path" }
        $absolute = Join-Path $Root $path
        Assert-RedMonitorOrdinaryGuidancePath $absolute
        $hash = if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            (Get-FileHash -LiteralPath $absolute -Algorithm SHA256 -ErrorAction Stop).Hash
        } elseif (Test-Path -LiteralPath $absolute) {
            throw "Source entry is not a file: $path"
        } else { '(missing)' }
        $files.Add($path, $hash)
        [void]$text.Append($path).Append([char]0).Append($hash).Append([char]0)
    }
    $identity = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text.ToString()))).ToLowerInvariant()
    return [pscustomobject]@{Identity=$identity;Files=$files}
}

function Get-RedMonitorSourceIdentity {
    [CmdletBinding()]
    param([string]$Root = (Join-Path $PSScriptRoot '..'))
    return (Get-RedMonitorSourceSnapshot -Root $Root).Identity
}

function Enter-RedMonitorOperation {
    param([Parameter(Mandatory)][string]$Scope)
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).ToLowerInvariant()
    $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$root|$Scope")))
    $mutex=[Threading.Mutex]::new($false,"Local\RedMonitor-$digest")
    try {
        if(-not $mutex.WaitOne(1800000)){throw "Timed out waiting for RedMonitor operation $Scope"}
    } catch [Threading.AbandonedMutexException] {
        $mutex.ReleaseMutex();$mutex.Dispose()
        throw "Interrupted RedMonitor operation $Scope. Inspect its outputs before retrying."
    } catch {
        $mutex.Dispose();throw
    }
    return $mutex
}

Export-ModuleMember -Function Get-RedMonitorMSBuild,Assert-RedMonitorOutputPath,Assert-RedMonitorOutputNotRunning,Get-RedMonitorSourceSnapshot,Get-RedMonitorSourceIdentity,Enter-RedMonitorOperation
