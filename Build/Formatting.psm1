Set-StrictMode -Version Latest

function Find-RedMonitorClangFormat {
    <# Prefer the selected Visual Studio C++ bundle over an unrelated PATH LLVM. Discovery only;
       format.ps1 separately verifies the selected executable and unchanged repository style. #>
    [CmdletBinding()]
    param([string]$VisualStudioInstallation='', [string]$PathFormatter='')
    $candidates = @(
        if ($VisualStudioInstallation) {
            Join-Path $VisualStudioInstallation 'VC/Tools/Llvm/x64/bin/clang-format.exe'
            Join-Path $VisualStudioInstallation 'VC/Tools/Llvm/bin/clang-format.exe'
        }
        if ($PathFormatter) { $PathFormatter }
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'Install Visual Studio C++ Clang tools or put clang-format.exe on PATH.'
}

Export-ModuleMember -Function Find-RedMonitorClangFormat
