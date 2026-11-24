Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root '.ci-engine/Tools/Modules/Ci.EngineBinding.psm1') -ErrorAction Stop
Import-Module (Resolve-CiPinnedEngineModule -ProjectRoot $root -Name 'VisualStudio.psm1') -Scope Local -ErrorAction Stop

function Get-RedMonitorVisualStudioInstallation {
    [CmdletBinding()]
    param()

    Find-CiVisualStudioInstallation
}

function Get-RedMonitorDefaultToolset {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Installation)

    Get-CiDefaultMsvcToolset -Installation $Installation
}

Export-ModuleMember -Function Get-RedMonitorVisualStudioInstallation, Get-RedMonitorDefaultToolset
