<#
.SYNOPSIS Exercises local SDK runtime routing and early refusal without launching native products.
.PARAMETER NativeMsBuildPath Optional selected Windows MSBuild for actual child output metadata controls.
.OUTPUTS Compiler-free control results and, when requested, retained native metadata below .build.
#>
[CmdletBinding()]param([string]$NativeMsBuildPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$file=Join-Path $root 'test.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($file,[ref]$null,[ref]$null)
$native=$env:CI_NATIVE_BUILDS_DISABLED;$actions=$env:GITHUB_ACTIONS
try{
    foreach($mode in @('compiler-free','hosted','missing-hash','wrong-profile','missing-skip-build')){
        $env:CI_NATIVE_BUILDS_DISABLED=$(if($mode -ceq 'compiler-free'){'true'}else{''})
        $env:GITHUB_ACTIONS=$(if($mode -ceq 'hosted'){'true'}else{''})
        $arguments=@{LocalSdkBuildReceipt='C:/synthetic-not-read/build.json';LocalSdkBuildSha256=('a'*64);Configuration='Release';SkipBuild=$true}
        switch($mode){'missing-hash'{$arguments.Remove('LocalSdkBuildSha256')};'wrong-profile'{$arguments.Configuration='Debug'};'missing-skip-build'{$arguments.SkipBuild=$false}}
        $failure='';try{& $file @arguments}catch{$failure=$_.Exception.Message}
        $expected=if($mode -in @('compiler-free','hosted')){'requires local Windows native execution'}else{'original build record/digest, Release and explicit SkipBuild'}
        if($failure -notmatch [regex]::Escape($expected)){throw "Local runtime early refusal failed for $mode : $failure"}
    }
}finally{$env:CI_NATIVE_BUILDS_DISABLED=$native;$env:GITHUB_ACTIONS=$actions}
function ActualAssignment([string]$Name){
    $nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -ceq $Name},$true))
    if($Name -ceq '$runtimeInput'){$nodes=@($nodes|Where-Object {$_.Right.Extent.Text -clike 'Open-CiLocalSdkApplicationRuntimeInput *'})}
    if($nodes.Count -ne 1){throw "Expected one actual runtime assignment: $Name"}
    $nodes[0].Extent.Text
}
function Open-CiLocalSdkApplicationRuntimeInput {
    param($ProjectRoot,$BuildReceipt,$ExpectedBuildSha256,$MSBuildPath)
    $script:request=$PSBoundParameters
    [pscustomobject]@{Role='synthetic runtime input';Closed=$false}
}
function Get-RedMonitorMSBuild {'C:/synthetic-not-launched/MSBuild.exe'}
$LocalSdkBuildReceipt='C:/synthetic-not-read/build.json';$LocalSdkBuildSha256='b'*64
# Invoke the exact production binding expression; no dependency, compiler or output query is run.
$bindingRoot=Join-Path $root ('.build/local-sdk-runtime-routing/'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($bindingRoot)
$bindingFile=Join-Path $bindingRoot 'actual-binding.ps1'
# A real script file supplies PSScriptRoot as in the public runner; an anonymous
# ScriptBlock.Create has no script path and would test a different binding.
[IO.File]::WriteAllText($bindingFile,(ActualAssignment '$runtimeInput'))
. $bindingFile
if($request.ProjectRoot -cne $bindingRoot -or $request.BuildReceipt -cne $LocalSdkBuildReceipt -or $request.ExpectedBuildSha256 -cne $LocalSdkBuildSha256 -or $runtimeInput.Role -cne 'synthetic runtime input'){
    throw 'Actual runtime binding redirected its original record, digest or input role.'
}
foreach($localSdkMode in @($false,$true)){
    . ([scriptblock]::Create((ActualAssignment '$runBase')))
    if($runBase -cne $(if($localSdkMode){'.build/local-sdk-test-runs/'}else{'.build/test-runs/'})){throw 'Local SDK results entered pinned test discovery.'}
}
$finalizer=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.TryStatementAst] -and $null -ne $n.Finally -and $n.Finally.Extent.Text.Contains('Close-CiLocalSdkApplicationRuntimeInput') -and $n.Finally.Extent.Text.Contains('receipt.json')},$true))
if($finalizer.Count -ne 1 -or $finalizer[0].Finally.Extent.Text.IndexOf('Close-CiLocalSdkApplicationRuntimeInput') -ge $finalizer[0].Finally.Extent.Text.IndexOf('receipt.json')){throw 'Runtime receipt is published before dependency close.'}
Write-Host 'PASS actual local runtime binding, pre-discovery refusals, separate discovery and close-before-result ownership; no native execution.'
if($NativeMsBuildPath){
    if(-not $IsWindows -or $env:GITHUB_ACTIONS -ceq 'true' -or $env:CI_NATIVE_BUILDS_DISABLED -ceq 'true'){throw 'Native output metadata controls require local Windows execution.'}
    Import-Module (Join-Path $root 'Build/Toolchain.psm1')
    $output=Assert-RedMonitorOutputPath (Join-Path $root ('.build/local-sdk-metadata/'+[guid]::NewGuid().ToString('N')))
    $projects=@(& git -C $root ls-files '*.vcxproj')
    foreach($project in $projects){
        $json=& $NativeMsBuildPath (Join-Path $root $project) '/nologo' '/v:quiet' '/p:Platform=x64' '/p:Configuration=Release' '/p:CiSdkContract=LocalUnpinnedAbiV1' ('/p:RedMonitorOutputRoot='+$output+'/') '-getProperty:OutDir,IntDir'
        if($LASTEXITCODE){throw "Child output evaluation failed: $project"}
        $properties=($json -join "`n"|ConvertFrom-Json).Properties
        foreach($name in @('OutDir','IntDir')){if(-not [IO.Path]::GetFullPath($properties.$name).StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Child $project escaped its actual $name"}}
    }
    [xml]$targets=[IO.File]::ReadAllText((Join-Path $root 'Directory.Build.targets'))
    $guard=$targets.Project.Target|Where-Object Name -CEQ RedMonitorValidateLocalSdkOutput
    if($null -eq $guard -or $guard.Condition -cne "'`$(CiSdkContract)'=='LocalUnpinnedAbiV1'" -or [string]$guard.Exec.Command -notmatch '-PreflightLocalOutputs'){
        throw 'Actual aggregate children lack their active output preflight.'
    }
    Write-Host "PASS actual isolated output metadata for $($projects.Count) native children; no compilation."
}
$global:LASTEXITCODE=0
