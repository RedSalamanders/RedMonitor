[CmdletBinding()]param([string]$NativeMsBuildPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$file=Join-Path $root 'Tools/Build-LocalSdkCandidate.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Local SDK command syntax is invalid.'}
function Find-Assignment([string]$Name){
    $matches=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -ceq $Name},$true))
    if($matches.Count -ne 1){throw "Expected one actual assignment: $Name"}
    return $matches[0].Extent.Text
}
function Get-RedMonitorMSBuild {'C:/synthetic-not-launched/MSBuild.exe'}
function Invoke-CiLocalSdkApplicationBuild {
    param($ProjectRoot,$Descriptor,$ExpectedDescriptorSha256,$Platform,$MSBuildPath,$BuildContract,$BuildNumber,$PrepareDependencies)
    $script:received=$PSBoundParameters
    [pscustomobject]@{Sentinel='original local broker result'}
}
$Descriptor='C:/synthetic-not-read/local snapshot.json';$DescriptorSha256='a'*64;$Platform='ARM64';$BuildNumber=123
. ([scriptblock]::Create((Find-Assignment '$buildContract')))
. ([scriptblock]::Create((Find-Assignment '$prepareDependencies')))
. ([scriptblock]::Create((Find-Assignment '$result')))
if($received.ProjectRoot -cne $root -or $received.Descriptor -cne $Descriptor -or $received.ExpectedDescriptorSha256 -cne $DescriptorSha256 -or $received.Platform -cne $Platform -or $received.BuildNumber -ne 123 -or $result.Sentinel -cne 'original local broker result'){throw 'Actual local SDK invocation redirected its source, descriptor, profile, version or result.'}
if($received.BuildContract.Count -ne 9 -or $received.BuildContract.buildFile -cne 'src/RedMonitor.vcxproj' -or $received.BuildContract.metadataProject -cne 'src/RedMonitor.vcxproj' -or $received.BuildContract.target -cne 'Build' -or $received.BuildContract.outputProperty -cne 'RedMonitorOutputRoot' -or $received.BuildContract.testsProperty -cne 'RedMonitorViewerTestsEnabled' -or $received.PrepareDependencies -isnot [scriptblock]){throw 'Viewer/support build, test surface, output or preparation binding changed.'}
$saved=$env:CI_NATIVE_BUILDS_DISABLED
try{
    $env:CI_NATIVE_BUILDS_DISABLED='true';$refused=$false
    try{& $file -Descriptor $Descriptor -DescriptorSha256 $DescriptorSha256}catch{if($_.Exception.Message -notmatch 'require local Windows native execution'){throw};$refused=$true}
    if(-not $refused){throw 'Compiler-free invocation reached native discovery.'}
}finally{$env:CI_NATIVE_BUILDS_DISABLED=$saved}
$appRoot=$root
$root=Join-Path $appRoot ('.build/local-sdk-routing/'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$restorer=@'
param($Platform,$OutputRoot)
if($env:REDMONITOR_TEST_LOCAL_RESTORE_FAIL -ceq 'true'){throw 'OWNED_RESTORE_CONTROL_FAILURE'}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'received.json'),(@{platform=$Platform;outputRoot=$OutputRoot}|ConvertTo-Json))
$global:LASTEXITCODE=0
'@
Set-Content -LiteralPath (Join-Path $root 'vcpkg-install.ps1') -Value $restorer
$script:leases=[Collections.Generic.List[Threading.Mutex]]::new()
function Enter-RedMonitorOperation {
    param([string]$Scope)
    if($Scope -cne 'local-sdk-dependency-restore'){throw 'Local preparation selected another operation namespace.'}
    $mutex=[Threading.Mutex]::new($false);[void]$mutex.WaitOne();$script:leases.Add($mutex);return $mutex
}
$saved=$env:REDMONITOR_TEST_LOCAL_RESTORE_FAIL
try{
    & $prepareDependencies
    $observed=Get-Content (Join-Path $root 'received.json') -Raw|ConvertFrom-Json
    if($observed.platform -cne 'ARM64' -or $observed.outputRoot -cne (Join-Path $root '.build/local-sdk-dependencies')){throw 'Actual preparation writes into ordinary or another platform inputs.'}
    $env:REDMONITOR_TEST_LOCAL_RESTORE_FAIL='true';$failed=$false
    try{& $prepareDependencies}catch{if($_.Exception.Message -notmatch 'OWNED_RESTORE_CONTROL_FAILURE'){throw};$failed=$true}
    if(-not $failed -or $leases.Count -ne 2){throw 'Restore failure was swallowed or did not acquire its own lease.'}
    foreach($lease in $leases){
        $disposed=$false
        try{[void]$lease.WaitOne(0)}catch [ObjectDisposedException]{$disposed=$true}
        if(-not $disposed){throw 'Local dependency preparation leaked its lease.'}
    }
}finally{$env:REDMONITOR_TEST_LOCAL_RESTORE_FAIL=$saved}
$global:LASTEXITCODE=0
Write-Host 'PASS actual local SDK routing, early refusal, isolated dependency preparation and failure cleanup; no native execution.'
if($NativeMsBuildPath){
    if(-not $IsWindows -or $env:GITHUB_ACTIONS -ceq 'true' -or $env:CI_NATIVE_BUILDS_DISABLED -ceq 'true'){throw 'Actual MSBuild metadata controls require local Windows native execution.'}
    $metadata=& $NativeMsBuildPath (Join-Path $appRoot 'support/RedMonitorSupport.vcxproj') '/nologo' '/v:quiet' '/p:Platform=x64' '/p:Configuration=Release' '/p:CiSdkContract=LocalUnpinnedAbiV1' '-getProperty:ExternalIncludePath,RedMonitorPackages,WindowsSDK_IncludePath'
    if($LASTEXITCODE){throw 'Support external-header metadata evaluation failed.'}
    $properties=($metadata -join "`n"|ConvertFrom-Json).Properties
    $expected=Join-Path $properties.RedMonitorPackages 'include'
    if($expected -notin $properties.ExternalIncludePath.Split(';')){throw 'Actual compiler property omits the selected local application dependencies from external headers.'}
    $systemIncludes=@($properties.WindowsSDK_IncludePath.Split(';')|Where-Object {$_})
    if(-not $systemIncludes.Count){throw 'Actual native metadata has no Windows SDK includes.'}
    foreach($include in $systemIncludes){if($include -notin $properties.ExternalIncludePath.Split(';')){throw 'App dependency classification replaced the system SDK external include defaults.'}}
    Write-Host 'PASS actual support metadata classifies selected app dependency headers as external; no compilation.'
}
$global:LASTEXITCODE=0
