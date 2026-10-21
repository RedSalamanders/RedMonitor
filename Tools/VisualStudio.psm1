# The Visual Studio installation and default MSVC toolset MSBuild compiles RedMonitor with, found once for every tool that must agree
# with it: build.ps1 and test-consumer.ps1 locate MSBuild through it, and vcpkg-install.ps1 pins vcpkg to the same installation
# and toolset (Tools/VcpkgTriplet.psm1). Nothing here installs or writes anything, or names a developer's installation.
Set-StrictMode -Version Latest

function Get-RedMonitorVisualStudioInstallation {
    <# The installation path of the newest Visual Studio, prereleases included, that has MSBuild. #>
    [CmdletBinding()]
    param()
    $vswhereCandidates = @(${env:ProgramFiles(x86)}, $env:ProgramFiles | Where-Object { $_ } |
            ForEach-Object { Join-Path $_ 'Microsoft Visual Studio/Installer/vswhere.exe' })
    $vswhere = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $vswhere) { throw 'Visual Studio Installer/vswhere.exe was not found.' }
    $installation = @(& $vswhere -latest -prerelease -products '*' -requires Microsoft.Component.MSBuild -property installationPath) |
        Where-Object { $_ } | Select-Object -First 1
    if (-not $installation) { throw 'Visual Studio with MSBuild was not found; install VS 2026 C++ tools.' }
    return [string]$installation
}

function Get-RedMonitorDefaultToolset {
    <# The MSVC toolset MSBuild compiles with when a project names none: the version in the installation's
       VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt, such as 14.51.36231, which its major.minor (14.51) selects. It
       can differ from the newest toolset installed side by side, which is what vcpkg would choose. A file that is missing or
       holds anything else fails here with what to repair, before anything is cloned or restored. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Installation)
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($Installation, 'VC', 'Auxiliary', 'Build', 'Microsoft.VCToolsVersion.default.txt'))
    $cause = "Cannot pin vcpkg to the default MSVC toolset of the Visual Studio installation at '$Installation'"
    if (-not [IO.File]::Exists($path)) {
        throw "${cause}: '$path' does not exist. Install the Desktop development with C++ workload (MSVC build tools) in the Visual Studio Installer, or repair the installation, and try again."
    }
    $text = [IO.File]::ReadAllText($path).Trim()
    $match = [regex]::Match($text, '^(?<majorMinor>[0-9]+\.[0-9]+)\.[0-9]+\z')
    if (-not $match.Success) {
        $shown = $text -replace '\s+', ' '
        if ($shown.Length -gt 60) { $shown = $shown.Substring(0, 60) + '...' }
        $holds = if ($shown) { "holds '$shown'" } else { 'is empty' }
        throw "${cause}: '$path' $holds, not a toolset version such as 14.51.36231. Repair the installation in the Visual Studio Installer so the file names the default toolset, and try again."
    }
    return [pscustomobject]@{ Installation = $Installation; VersionFile = $path; Version = $text; MajorMinor = $match.Groups['majorMinor'].Value }
}

Export-ModuleMember -Function Get-RedMonitorVisualStudioInstallation, Get-RedMonitorDefaultToolset
