Set-StrictMode -Version Latest

function Write-RedMonitorBuildBanner {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Platform,
          [Parameter(Mandatory)][string]$Configuration,
          [switch]$ProductionOnly,
          [ValidateSet('Auto','Always','Never')][string]$ColorMode='Auto')
    $color = $ColorMode -eq 'Always' -or
        ($ColorMode -eq 'Auto' -and -not [Console]::IsOutputRedirected -and
         $null -eq [Environment]::GetEnvironmentVariable('NO_COLOR','Process'))
    $art = @(
        '  ____          _ __  __             _ _             ',
        ' |  _ \ ___  __| |  \/  | ___  _ __ (_) |_ ___  _ __ ',
        ' | |_) / _ \/ _` | |\/| |/ _ \| ''_ \| | __/ _ \| ''__|',
        ' |  _ <  __/ (_| | |  | | (_) | | | | | || (_) | |   ',
        ' |_| \_\___|\__,_|_|  |_|\___/|_| |_|_|\__\___/|_|   ',
        '',
        '       __/\___/\____/\___   TRACE > CAPTURE > VIEW'
    )
    $colors = @('DarkRed','Red','Magenta','Cyan','Green','DarkGray','Cyan')
    Write-Host ''
    for ($index=0; $index -lt $art.Count; ++$index) {
        if ($color) { Write-Host $art[$index] -ForegroundColor $colors[$index] }
        else { Write-Host $art[$index] }
    }
    $targets = if ($ProductionOnly) { 'viewer + satellites (production)' } else { 'viewer + satellites + console tests' }
    $profile = "Target: RedMonitor | $Platform | $Configuration | $targets"
    if ($color) { Write-Host $profile -ForegroundColor Yellow }
    else { Write-Host $profile }
    Write-Host ''
}

Export-ModuleMember -Function Write-RedMonitorBuildBanner
