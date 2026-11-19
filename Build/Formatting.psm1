Set-StrictMode -Version Latest

function Get-RedMonitorClangFormat {
    <# The formatter format.ps1 uses, shared with validation identity: Install-CiFormatter from this checkout's
       pinned .ci-engine installs and verifies the clang-format that the engine's Policy/clang-format.json pins
       under .build/shared-format. There is no repository pin and no Visual Studio or PATH lookup. #>
    [CmdletBinding()]
    param([string]$Root=(Join-Path $PSScriptRoot '..'))
    $checkout=[IO.Path]::GetFullPath($Root)
    $module=Join-Path $checkout '.ci-engine/Tools/Modules/Ci.Format.psm1'
    if(-not(Test-Path -LiteralPath $module -PathType Leaf)){
        throw 'Formatting needs the shared CI engine in .ci-engine at the engine.ref that .ci/project.json pins.'
    }
    Import-Module $module -ErrorAction Stop
    return Install-CiFormatter $checkout
}

Export-ModuleMember -Function Get-RedMonitorClangFormat
