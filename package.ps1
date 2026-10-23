<#
.SYNOPSIS
Packages a successful exact-source viewer build and its full runtime/data closure.
.PARAMETER Platform
x64 or ARM64 target.
.PARAMETER Configuration
Release by default; Debug and ASan Debug are diagnostic packages.
.PARAMETER PassThru
Return the generated ZIP, staging and extraction paths for a verified consumer staging operation.
#>
[CmdletBinding()]
param([ValidateSet('x64','ARM64')][string]$Platform='x64',
      [ValidateSet('Debug','Release','ASan Debug')][string]$Configuration='Release', [switch]$PassThru)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/Toolchain.psm1') -Force
$lease=Enter-RedMonitorOperation "artifact-$Platform-$Configuration"
try {
$output=Join-Path $PSScriptRoot ".build/$Platform/$Configuration"
$receipt=Get-Content -LiteralPath (Join-Path $output 'build-receipt.json') -Raw|ConvertFrom-Json
if(-not $receipt.passed -or $receipt.sourceIdentity -cne (Get-RedMonitorSourceIdentity)){throw 'Build exact current source before packaging.'}
if($Configuration -eq 'Release' -and $receipt.viewerTestsEnabled){throw 'A distributable Release viewer must be built with ViewerTests false.'}
foreach($artifact in $receipt.artifacts){
    if((Get-FileHash -LiteralPath (Assert-RedMonitorOutputPath (Join-Path $output $artifact.path))).Hash -cne $artifact.sha256){throw "Changed artifact: $($artifact.path)"}
}
$root=Assert-RedMonitorOutputPath (Join-Path $PSScriptRoot ('.build/packages/'+[guid]::NewGuid().ToString('N')))
$stage=Join-Path $root 'RedMonitor'
New-Item -ItemType Directory -Path $stage -Force|Out-Null
foreach($name in 'RedMonitor.exe','SettingsStore.schema.json','Themes','Lang'){
    Copy-Item -LiteralPath (Join-Path $output $name) -Destination $stage -Recurse
}
if($Configuration -eq 'ASan Debug'){
    $runtimes=@(Get-ChildItem -LiteralPath $output -Filter '*asan*.dll')
    if(-not $runtimes){throw 'ASan package is missing its runtime.'}
    $runtimes|Copy-Item -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE.txt') -Destination $stage
$dxuiPin=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Dependencies/DxUi.lock.json') -Raw|ConvertFrom-Json
Copy-Item -LiteralPath (Join-Path $PSScriptRoot ".build/dependencies/DxUi/source/$($dxuiPin.commit)/LICENSE.txt") -Destination (Join-Path $stage 'DxUi-LICENSE.txt')
if($Configuration -eq 'Release'){
    Import-Module (Join-Path $PSScriptRoot 'Tools/VisualStudio.psm1') -Force
    $installation=Get-RedMonitorVisualStudioInstallation
    $architecture=$Platform.ToLowerInvariant()
    $crt=@(Get-ChildItem -LiteralPath (Join-Path $installation 'VC/Redist/MSVC') -Directory|Where-Object Name -match '^\d+\.\d+\.\d+$'|
        Sort-Object {[version]$_.Name} -Descending|ForEach-Object {
            Get-ChildItem -LiteralPath (Join-Path $_.FullName $architecture) -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
        })|Select-Object -First 1
    if(-not $crt -or -not(Test-Path -LiteralPath (Join-Path $crt.FullName 'vcruntime140.dll'))){throw 'Matching distributable VC CRT is missing.'}
    Get-ChildItem -LiteralPath $crt.FullName -File -Filter '*.dll'|Copy-Item -Destination $stage
}
$triplet=if($Platform -eq 'x64'){'x64-windows-static-md'}else{'arm64-windows-static-md'}
foreach($dependency in 'wil','yyjson'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ".build/vcpkg_installed/$Platform/$triplet/share/$dependency/copyright") -Destination (Join-Path $stage "$dependency-LICENSE.txt")
}
Copy-Item -LiteralPath (Join-Path $output 'build-receipt.json') -Destination $stage
$packageFiles=@(Get-ChildItem -LiteralPath $stage -Recurse -File|ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($stage,$_.FullName);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
[ordered]@{schemaVersion=1;commit=(& git -C $PSScriptRoot rev-parse HEAD);apiRevision=1;platform=$Platform;configuration=$Configuration;sourceIdentity=$receipt.sourceIdentity;files=$packageFiles}|
    ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $stage 'package-receipt.json') -Encoding utf8
$zip=Join-Path $root "RedMonitor-$Platform-$($Configuration.Replace(' ','-')).zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip
$extracted=Join-Path $root 'extracted'
Expand-Archive -LiteralPath $zip -DestinationPath $extracted
foreach($file in $packageFiles){
    if((Get-FileHash -LiteralPath (Join-Path $extracted $file.path)).Hash -cne $file.sha256){throw "Package extraction changed $($file.path)"}
}
if((Test-Path -LiteralPath (Join-Path $extracted 'Common.dll')) -or (Test-Path -LiteralPath (Join-Path $extracted 'yyjson.dll'))){
    throw 'Standalone package contains a legacy shared DLL.'
}
if($Configuration -eq 'Release' -and ($Platform -eq 'x64' -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64')){
    $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $extracted 'RedMonitor.exe'))
    $start.ArgumentList.Add('--runtime-contract')
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.Environment['PATH']=Join-Path $env:SystemRoot 'System32'
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try{
        if(-not $process.Start()){throw 'Could not launch the extracted runtime contract.'}
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill($true);$process.WaitForExit();throw 'Owned runtime contract timed out.'}
        [IO.File]::WriteAllText((Join-Path $root 'runtime-contract.log'),$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult())
        if($process.ExitCode -ne 0){throw "Extracted runtime contract failed: $($process.ExitCode)"}
    }finally{$process.Dispose()}
}
Write-Host "Package: $zip"
if($PassThru){[pscustomobject]@{zip=$zip;stage=$stage;extracted=$extracted}}
} finally {$lease.ReleaseMutex();$lease.Dispose()}
