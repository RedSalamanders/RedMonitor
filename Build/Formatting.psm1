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

Export-ModuleMember -Function Find-RedMonitorClangFormat
