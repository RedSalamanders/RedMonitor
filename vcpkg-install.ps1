<#!
.SYNOPSIS
Installs the RedMonitor vcpkg manifest dependencies for x64, ARM64, or both.

.DESCRIPTION
Uses the repository and commit pinned by vcpkg-tool.json. The managed vcpkg checkout, downloads, build trees,
packages, and installed trees all live beneath .build. Each platform receives a private install root so one
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
#>
[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64', 'All')]
    [string] $Platform = 'x64',
    [string] $OutputRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $repoRoot 'Tools/VisualStudio.psm1') -Force
Import-Module (Join-Path $repoRoot 'Tools/VcpkgTriplet.psm1') -Force
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

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $toolRoot '.git') -PathType Container)) {
    if (Test-Path -LiteralPath $toolRoot) {
        throw "The managed vcpkg path exists but is not a Git checkout: $toolRoot"
    }

    Write-Host "Cloning pinned vcpkg tooling into $toolRoot" -ForegroundColor Cyan
    # Set only this managed checkout: relocated consumers may exceed traditional Win32 path limits.
    & git.exe clone -c core.longpaths=true --filter=blob:none $repository $toolRoot
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed with exit code $LASTEXITCODE."
    }
}

$origin = & git.exe -C $toolRoot remote get-url origin
if ($LASTEXITCODE -ne 0 -or $origin.TrimEnd('/') -ne $repository.TrimEnd('/')) {
    throw "The managed vcpkg checkout does not use the pinned repository: $repository"
}

$dirty = & git.exe -C $toolRoot status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the managed vcpkg checkout.'
}
if ($dirty) {
    throw "The managed vcpkg checkout contains local changes: $toolRoot"
}

$head = & git.exe -C $toolRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or $head -ne $commit) {
    Write-Host "Selecting pinned vcpkg commit $commit" -ForegroundColor Cyan
    & git.exe -C $toolRoot fetch --depth 1 origin $commit
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to fetch pinned vcpkg commit $commit."
    }
    & git.exe -C $toolRoot checkout --detach $commit
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to check out pinned vcpkg commit $commit."
    }
}

$vcpkg = Join-Path $toolRoot 'vcpkg.exe'
$stampedCommit = if (Test-Path -LiteralPath $toolStampPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $toolStampPath).Trim()
} else {
    ''
}
if (-not (Test-Path -LiteralPath $vcpkg -PathType Leaf) -or $stampedCommit -ne $commit) {
    Write-Host 'Bootstrapping vcpkg...' -ForegroundColor Cyan
    & (Join-Path $toolRoot 'bootstrap-vcpkg.bat') -disableMetrics
    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg bootstrap failed with exit code $LASTEXITCODE."
    }
    Set-Content -LiteralPath $toolStampPath -Value $commit -Encoding ascii
}

$platforms = if ($Platform -eq 'All') { @('x64', 'ARM64') } else { @($Platform) }
foreach ($targetPlatform in $platforms) {
    $platformScope = $targetPlatform
    $triplet = if ($targetPlatform -eq 'ARM64') { 'arm64-windows-static-md' } else { 'x64-windows-static-md' }
    $installRoot = Join-Path $buildRoot "vcpkg_installed\$platformScope"
    $buildTreesRoot = Join-Path $buildRoot "vcpkg_buildtrees\$platformScope"
    $packagesRoot = Join-Path $buildRoot "vcpkg_packages\$platformScope"
    $downloadsRoot = Join-Path $buildRoot 'vcpkg_downloads'
    # The pinned checkout's own triplet, copied and pinned; vcpkg takes an overlay in place of the triplet of the same name.
    $overlay = Update-RedMonitorVcpkgOverlayTriplet -StockTripletPath (Join-Path $toolRoot "triplets/$triplet.cmake") -Toolset $toolset `
        -OutputDirectory (Join-Path $buildRoot "vcpkg-triplets\$platformScope")
    Write-Host "Overlay triplet $($overlay.Path) $(if ($overlay.Changed) { 'written' } else { 'unchanged' })" -ForegroundColor Cyan

    Write-Host "Installing RedMonitor dependencies ($triplet)" -ForegroundColor Cyan
    $arguments = @(
        'install',
        "--triplet=$triplet",
        "--x-manifest-root=$repoRoot",
        "--x-install-root=$installRoot",
        "--x-buildtrees-root=$buildTreesRoot",
        "--x-packages-root=$packagesRoot",
        "--downloads-root=$downloadsRoot",
        "--overlay-triplets=$($overlay.Directory)"
    )
    & $vcpkg @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg install failed for $triplet with exit code $LASTEXITCODE."
    }
}

Write-Host 'vcpkg dependencies are ready.' -ForegroundColor Green
