<#!
.SYNOPSIS
Installs the RedMonitor vcpkg manifest dependencies for x64, ARM64, or both.

.DESCRIPTION
Uses the repository and commit pinned by vcpkg-tool.json, in a complete clone: vcpkg reads versioned ports with Git
commands that cannot fetch a missing object, so a partial clone left by an earlier version is completed once.
The managed vcpkg checkout, downloads, build trees, packages, and installed trees all live beneath .build. Each platform receives a private install root so one
manifest install cannot purge the other platform's package metadata.

vcpkg builds with the Visual Studio installation and MSVC toolset that build.ps1's MSBuild uses, not the newest
toolset it finds. The installation is the one Tools/VisualStudio.psm1 discovers for build.ps1 and the toolset is
that installation's default (VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt); a missing or malformed
version file fails before anything is cloned. Each platform gets an overlay triplet beneath the output root,
vcpkg-triplets\<platform>\<triplet>.cmake: the pinned vcpkg checkout's triplet plus the two pins (VCPKG_VISUAL_STUDIO_PATH
and VCPKG_PLATFORM_TOOLSET_VERSION), rewritten only when its contents change. Changing the triplet changes vcpkg's
package ABI hash, so the first restore after a change rebuilds the packages.

.PARAMETER Platform
Target platform: x64, ARM64, or All.

.PARAMETER OutputRoot
Directory that holds the managed vcpkg checkout, overlay triplets, downloads, build trees, packages, and installed
trees. Defaults to this checkout's .build.

.PARAMETER Asan
Restore the instrumented ASan Debug tree for the selected architecture.
#>
[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64', 'All')]
    [string] $Platform = 'x64',
    [string] $OutputRoot = '',
    [switch] $Asan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $repoRoot 'Tools/VisualStudio.psm1') -Force
Import-Module (Join-Path $repoRoot 'Tools/VcpkgTriplet.psm1') -Force
Import-Module (Join-Path $repoRoot '.ci-engine/Tools/Modules/Ci.EngineBinding.psm1') -ErrorAction Stop
foreach ($module in @('VcpkgCheckout.psm1', 'VcpkgInstall.psm1')) {
    Import-Module (Resolve-CiPinnedEngineModule -ProjectRoot $repoRoot -Name $module) -Scope Local -ErrorAction Stop
}
$buildRoot = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $repoRoot '.build' }
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.build'))
if ($buildRoot -ine $allowedRoot -and -not $buildRoot.StartsWith($allowedRoot+'\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "RedMonitor dependency outputs must remain beneath '$allowedRoot'."
}
for ($component=[IO.DirectoryInfo]::new($buildRoot); $component; $component=$component.Parent) {
    if ($component.Exists -and ($component.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Dependency output contains a reparse point: $($component.FullName)"
    }
}
$toolRoot = Join-Path $buildRoot 'vcpkg-tool'
$toolStampPath = Join-Path $buildRoot 'vcpkg-tool.commit'
$toolIdentityPath = Join-Path $repoRoot 'vcpkg-tool.json'
$manifestPath = Join-Path $repoRoot 'vcpkg.json'

if (-not (Get-Command 'git.exe' -ErrorAction SilentlyContinue)) {
    throw 'Git was not found. Install Git for Windows and ensure git.exe is on PATH.'
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "The vcpkg manifest was not found: $manifestPath"
}

$toolIdentity = Get-Content -Raw -LiteralPath $toolIdentityPath | ConvertFrom-Json
$repository = [string] $toolIdentity.repository
$commit = [string] $toolIdentity.commit
if ([string]::IsNullOrWhiteSpace($repository) -or $commit -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'vcpkg-tool.json must contain a repository URL and a full 40-character commit hash.'
}

# vcpkg picks the newest MSVC toolset of the Visual Studio installation it prefers; build.ps1's MSBuild compiles with the
# installation's default toolset. Find both the way build.ps1 does, here, before anything is cloned or downloaded, so a
# broken installation fails at once and every triplet below is pinned to what MSBuild uses.
$installation = Get-RedMonitorVisualStudioInstallation
$toolset = Get-RedMonitorDefaultToolset -Installation $installation
Write-Host "Visual Studio: $installation" -ForegroundColor Cyan
Write-Host "MSVC toolset:  $($toolset.Version), the default MSBuild compiles with; vcpkg is pinned to $($toolset.MajorMinor)" -ForegroundColor Cyan

Initialize-CiVcpkgCheckout -ProjectRoot $repoRoot -Path $toolRoot -Repository $repository -Commit $commit

$vcpkg = Initialize-CiVcpkgExecutable -ProjectRoot $repoRoot -ToolRoot $toolRoot -StampPath $toolStampPath -Commit $commit

$platforms = if ($Platform -eq 'All') { @('x64', 'ARM64') } else { @($Platform) }
foreach ($targetPlatform in $platforms) {
    $platformScope = $targetPlatform
    $triplet = if ($targetPlatform -eq 'ARM64') { 'arm64-windows' } else { 'x64-windows' }
    if ($Asan) {
        $platformScope += '-asan'
        $triplet += '-asan'
        $tripletSource = Join-Path $repoRoot "Build/vcpkg-triplets/$triplet.cmake"
    } else {
        $tripletSource = Join-Path $toolRoot "triplets/$triplet.cmake"
    }
    $installRoot = Join-Path $buildRoot "vcpkg_installed\$platformScope"
    $buildTreesRoot = Join-Path $buildRoot "vcpkg_buildtrees\$platformScope"
    $packagesRoot = Join-Path $buildRoot "vcpkg_packages\$platformScope"
    $downloadsRoot = Join-Path $buildRoot 'vcpkg_downloads'
    $overlay = Update-RedMonitorVcpkgOverlayTriplet -StockTripletPath $tripletSource -Toolset $toolset `
        -OutputDirectory (Join-Path $buildRoot "vcpkg-triplets\$platformScope")
    Write-Host "Overlay triplet $($overlay.Path) $(if ($overlay.Changed) { 'written' } else { 'unchanged' })" -ForegroundColor Cyan

    Write-Host "Installing RedMonitor dependencies ($triplet)" -ForegroundColor Cyan
    $arguments = Get-CiVcpkgManifestInstallArguments -ProjectRoot $repoRoot -Triplet $triplet `
        -InstallRoot $installRoot -BuildTreesRoot $buildTreesRoot -PackagesRoot $packagesRoot `
        -DownloadsRoot $downloadsRoot -OverlayTriplets $overlay.Directory
    if ($Asan) {
        $arguments += '--binarysource=clear'
    }
    & $vcpkg @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg install failed for $triplet with exit code $LASTEXITCODE."
    }
}

Write-Host 'vcpkg dependencies are ready.' -ForegroundColor Green
