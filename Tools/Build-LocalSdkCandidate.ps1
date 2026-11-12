<#
.SYNOPSIS Builds the viewer and its normal Release test union against an explicit local SDK.
.PARAMETER Descriptor Absolute producer local SDK snapshot descriptor.
.PARAMETER DescriptorSha256 Independently retained SHA-256 of that descriptor.
.PARAMETER Platform x64 or ARM64 Release target; cross-compilation is not native execution.
.PARAMETER BuildNumber Resource build number for this operation.
.OUTPUTS Fresh .build/local-unpinned viewer/test union, logs, actual link proof and a local-only build record.
.NOTES Requires local Windows, exact pinned shared engine, selected native MSBuild and matching API/ABI.
Restores app dependencies only below .build/local-sdk-dependencies, separate from ordinary profile inputs.
Local operations serialize by platform; shared local dependency bootstrap/restore has its own short lease.
The viewer and support archive receive the SDK guard; every native aggregate child receives output preflight.
Managed pins, ordinary outputs, pinned tests, packages, installation and publication are unchanged.
No application is launched and no qualification is granted. Use test.ps1's explicit local SDK mode for runtime.
.EXAMPLE ./Tools/Build-LocalSdkCandidate.ps1 -Descriptor Z:/src/DxUi/.build/local-sdk-capture/example/local-unpinned-snapshot.json -DescriptorSha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Descriptor,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$DescriptorSha256,
    [ValidateSet('x64','ARM64')][string]$Platform='x64',[ValidateRange(0,65535)][int]$BuildNumber=0)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows -or $env:GITHUB_ACTIONS -ceq 'true' -or $env:CI_NATIVE_BUILDS_DISABLED -ceq 'true'){throw 'Local SDK candidate builds require local Windows native execution.'}
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1')
Import-Module (Join-Path $root '.ci-engine/Tools/Modules/Ci.LocalSdkBuild.psm1') -ErrorAction Stop
$buildContract=[ordered]@{buildFile='RedMonitor.proj';metadataProject='src/RedMonitor.vcxproj';target='Build';sdkProperty='RedMonitorDxUiSdkRoot';engineProperty='RedMonitorCiEngineRoot';outputProperty='RedMonitorOutputRoot';testsProperty='RedMonitorViewerTestsEnabled';versionProperty='RedMonitorBuildNumber';executable='RedMonitor.exe'}
$prepareDependencies={
    $restore=Enter-RedMonitorOperation 'local-sdk-dependency-restore'
    try{
        & (Join-Path $root 'vcpkg-install.ps1') -Platform $Platform -OutputRoot (Join-Path $root '.build/local-sdk-dependencies')
        if(-not $? -or $LASTEXITCODE){throw 'Local SDK application dependency restore failed.'}
    }finally{$restore.ReleaseMutex();$restore.Dispose()}
}
$lease=Enter-RedMonitorOperation ("local-sdk-native-"+$Platform)
try{
    $result=Invoke-CiLocalSdkApplicationBuild -ProjectRoot $root -Descriptor $Descriptor -ExpectedDescriptorSha256 $DescriptorSha256 -Platform $Platform -MSBuildPath (Get-RedMonitorMSBuild) -BuildContract $buildContract -BuildNumber $BuildNumber -PrepareDependencies $prepareDependencies
}finally{$lease.ReleaseMutex();$lease.Dispose()}
Write-Host 'LOCAL_UNPINNED_BUILD: tests, repository and production qualification remain NOT_EVALUATED.'
$result
