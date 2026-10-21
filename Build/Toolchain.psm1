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

function Get-RedMonitorSourceIdentity {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $files = @(Get-ChildItem -LiteralPath $root -File -Force)
    foreach ($directory in Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object Name -notin '.git','.build','.vs','Measurements') {
        $files += @(Get-ChildItem -LiteralPath $directory.FullName -File -Recurse -Force)
    }
    $rows = foreach ($file in $files | Sort-Object FullName) {
        [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/') + ':' + (Get-FileHash -LiteralPath $file.FullName).Hash
    }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($rows -join "`n")))).ToLowerInvariant()
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

Export-ModuleMember -Function Get-RedMonitorMSBuild,Assert-RedMonitorOutputPath,Assert-RedMonitorOutputNotRunning,Get-RedMonitorSourceIdentity,Enter-RedMonitorOperation
