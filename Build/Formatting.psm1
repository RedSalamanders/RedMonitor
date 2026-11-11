Set-StrictMode -Version Latest

function Find-RedMonitorClangFormat {
    <# Prefer the repository install, then the selected Visual Studio bundle, then PATH. Discovery only;
       format.ps1 separately verifies the selected executable and unchanged repository style. #>
    [CmdletBinding()]
    param([string]$VisualStudioInstallation='', [string]$PathFormatter='', [string]$RepositoryFormatter='')
    $candidates = @(
        if ($RepositoryFormatter) { $RepositoryFormatter }
        if ($VisualStudioInstallation) {
            Join-Path $VisualStudioInstallation 'VC/Tools/Llvm/x64/bin/clang-format.exe'
            Join-Path $VisualStudioInstallation 'VC/Tools/Llvm/bin/clang-format.exe'
        }
        if ($PathFormatter) { $PathFormatter }
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'Run ./Tools/Install-ClangFormat.ps1 or provide the pinned clang-format through Visual Studio C++ Clang tools or PATH.'
}

function Get-RedMonitorClangFormat {
    <# Canonical selected formatter discovery/version check, shared with validation identity. #>
    [CmdletBinding()]
    param([string]$Root=(Join-Path $PSScriptRoot '..'))
    Import-Module (Join-Path $PSScriptRoot 'AgentGuidance.psm1') -ErrorAction Stop
    $pin=Get-Content -LiteralPath (Join-Path $Root 'Build/clang-format.json') -Raw|ConvertFrom-Json
    $repositoryFormatter=Join-Path $Root ('.build/format/'+$pin.entryPath)
    $installation='';$pathFormatter=''
    if(-not(Test-Path -LiteralPath $repositoryFormatter -PathType Leaf)){
        try{
            $msbuild=Get-RedMonitorMSBuild
            $installation=([IO.FileInfo]$msbuild).Directory.Parent.Parent.Parent.FullName
        }catch [System.Management.Automation.RuntimeException]{
            Write-Verbose "Visual Studio formatter discovery unavailable: $($_.Exception.Message)"
        }
        $command=Get-Command clang-format.exe -ErrorAction SilentlyContinue|Select-Object -First 1
        if($command){$pathFormatter=$command.Source}
    }
    $formatter=Find-RedMonitorClangFormat -VisualStudioInstallation $installation -PathFormatter $pathFormatter -RepositoryFormatter $repositoryFormatter
    Assert-RedMonitorOrdinaryGuidancePath $formatter
    $version=@(& $formatter --version)
    if($LASTEXITCODE -ne 0 -or ($version -join '') -notmatch ('^clang-format version '+[regex]::Escape($pin.version)+'(?:\s|$)')){
        throw "Formatting requires clang-format $($pin.version). Run ./Tools/Install-ClangFormat.ps1. Found: $($version -join ' ')"
    }
    return $formatter
}

Export-ModuleMember -Function Find-RedMonitorClangFormat,Get-RedMonitorClangFormat
