# Runs one shared independent scope while retaining RedMonitor's immutable attempt record.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('Validation','Format','Tooling')][string]$Scope)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'Build/Toolchain.psm1')
Import-Module (Join-Path $root 'Build/IndependentValidation.psm1')
$commands = @{
    Validation=@{ path='validate.ps1'; arguments=@() }
    Format=@{ path='format.ps1'; arguments=@('-Check') }
    Tooling=@{ path='Tests/Tooling.Tests.ps1'; arguments=@() }
}
$command = $commands[$Scope]
$lease = Enter-RedMonitorOperation -Scope 'independent-validation'
try {
    $identity = Get-RedMonitorIndependentIdentity -Root $root
    # The shared runner owns reuse. Every invocation here is a new immutable attempt.
    Invoke-RedMonitorIndependentCheck $root $Scope {
        $arguments = $command.arguments
        $global:LASTEXITCODE = 0
        & (Join-Path $root $command.path) @arguments
        if (-not $? -or $LASTEXITCODE) {
            throw "Validation failed: $($command.path) (exit $LASTEXITCODE)."
        }
    } $identity
} finally {
    $lease.ReleaseMutex()
    $lease.Dispose()
}
