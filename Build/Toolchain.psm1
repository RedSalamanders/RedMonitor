Set-StrictMode -Version Latest

function Get-RedMonitorMSBuild {
    Import-Module (Join-Path $PSScriptRoot '../Tools/VisualStudio.psm1') -Force
    $installation = Get-RedMonitorVisualStudioInstallation
    $relative = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') {
        'MSBuild/Current/Bin/arm64/MSBuild.exe'
    } else { 'MSBuild/Current/Bin/amd64/MSBuild.exe' }
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

function Invoke-RedMonitorGitText {
    param([string]$Root,[string[]]$Arguments)
    $start=[Diagnostics.ProcessStartInfo]::new('git')
    foreach($argument in @('-C',$Root)+$Arguments){$start.ArgumentList.Add($argument)}
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false,$true)
    $start.StandardErrorEncoding=[Text.UTF8Encoding]::new($false,$true)
    $process=[Diagnostics.Process]::Start($start)
    try{
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);$process.WaitForExit();throw 'Git source inventory timed out after 30 seconds.'}
        if($process.ExitCode){throw "Git source inventory failed ($($process.ExitCode)): $($stderr.GetAwaiter().GetResult().Trim())"}
        return $stdout.GetAwaiter().GetResult()
    }finally{$process.Dispose()}
}

function Get-RedMonitorChangePlan {
    [CmdletBinding()]
    param([string]$Root=(Join-Path $PSScriptRoot '..'),[string]$BaseRef='origin/main')
    $Root=[IO.Path]::GetFullPath($Root)
    Import-Module (Join-Path $PSScriptRoot 'AgentGuidance.psm1') -ErrorAction Stop
    Assert-RedMonitorOrdinaryGuidancePath $Root
    try{
        $base=(Invoke-RedMonitorGitText $Root @('rev-parse','--verify','--end-of-options',($BaseRef+'^{commit}'))).Trim()
        $merge=(Invoke-RedMonitorGitText $Root @('merge-base',$base,'HEAD')).Trim()
        $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($arguments in @(
            @('diff','--no-ext-diff','--no-textconv','--name-only','--no-renames','-z',$merge,'HEAD','--'),
            @('diff','--no-ext-diff','--no-textconv','--cached','--name-only','--no-renames','-z','--'),
            @('diff','--no-ext-diff','--no-textconv','--name-only','--no-renames','-z','--'),
            @('ls-files','--others','--exclude-standard','-z'))){
            foreach($path in (Invoke-RedMonitorGitText $Root $arguments).Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)){[void]$paths.Add($path)}
        }
    }catch{
        # Missing Git/base/shared history never supplies permission to omit native work.
        return [pscustomobject]@{kind='Native';paths=@();reason='Comparison unavailable; conservative Debug coverage. '+$_.Exception.Message}
    }
    $ordered=[string[]]@($paths);[Array]::Sort($ordered,[StringComparer]::Ordinal)
    $native=$false
    foreach($path in $ordered){
        if($path -match '(^/|(^|/)\.\.(/|$)|:|\\)'){throw "Invalid changed Git path: $path"}
        Assert-RedMonitorOrdinaryGuidancePath (Join-Path $Root $path)
        if($path -notmatch '^(README|AGENTS|CLAUDE|CHANGELOG)\.md$|^Tests/README\.md$|^(Specs|docs|Changes|\.agents|\.github/skills)/.*\.md$'){$native=$true}
    }
    return [pscustomobject]@{kind=$(if($native){'Native'}elseif($ordered.Count){'Prose'}else{'None'});paths=$ordered;
        reason=$(if($native){'Native/build/test or unknown inputs changed.'}elseif($ordered.Count){'Only owned prose changed; independent validation remains required.'}else{'No changed input since the branch merge base.'})}
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
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($path in (Invoke-RedMonitorGitText $Root @('ls-files','--cached','--others','--exclude-standard','-z')).Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)) {
        [void]$paths.Add($path)
    }
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

Export-ModuleMember -Function Get-RedMonitorMSBuild,Assert-RedMonitorOutputPath,Assert-RedMonitorOutputNotRunning,Get-RedMonitorSourceSnapshot,Get-RedMonitorSourceIdentity,Enter-RedMonitorOperation,Get-RedMonitorChangePlan
