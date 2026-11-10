<#
.SYNOPSIS Exercises actual SDK MSBuild admission with a held verified reader and incompatible consumer profiles.
.PARAMETER Descriptor Independent local pinned SDK descriptor beneath this repository's .build.
.PARAMETER Platform Native SDK target x64 or ARM64; no product or desktop is launched.
.OUTPUTS Retained MSBuild logs and a policy-case receipt under .build/sdk-input-controls.
.NOTES Requires the exact pinned shared engine, restored SDK identity inputs and Visual Studio MSBuild.
This compiler-dependent control is explicit, never part of compiler-free PR tooling or product qualification.
.EXAMPLE ./Tests/Test-SdkInputs.Native.ps1 -Descriptor Z:/src/RedMonitor/.build/sdk-input.json -Platform x64
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Descriptor,[ValidateSet('x64','ARM64')][string]$Platform='x64')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
$engine=Join-Path $root '.ci-engine'
$pin=Get-Content (Join-Path $root '.ci/project.json') -Raw|ConvertFrom-Json
$head=(& git -C $engine rev-parse HEAD).Trim()
if($LASTEXITCODE -or $head -cne $pin.engine.ref){throw 'SDK controls require the exact pinned engine.'}
$dirty=@(& git -C $engine status --porcelain --untracked-files=all)
if($LASTEXITCODE -or $dirty.Count){throw 'SDK controls require a clean engine.'}
Import-Module (Join-Path $engine 'Tools/Modules/Ci.SdkConsumer.psm1')
$lock=Get-Content (Join-Path $root 'Dependencies/DxUi.lock.json') -Raw|ConvertFrom-Json
$sdk=Open-CiPinnedSdkInput -ProjectRoot $root -Descriptor $Descriptor -ExpectedSourceCommit $lock.commit -ExpectedApiRevision $lock.apiRevision -Platform $Platform -Configuration Release
if($null -eq $sdk){throw 'SDK controls require an exact input hit.'}
$run=Assert-RedMonitorOutputPath (Join-Path $root ('.build/sdk-input-controls/'+[guid]::NewGuid().ToString('N')))
[void][IO.Directory]::CreateDirectory($run)
$primary=$null
try{
    $manifest=Get-Content (Join-Path $sdk.SdkRoot 'sdk-manifest.json') -Raw|ConvertFrom-Json
    $xml=@'
<Project>
  <PropertyGroup>
    <RedMonitorRoot>@ROOT@</RedMonitorRoot><RedMonitorDxUiSdkRoot>@SDK@</RedMonitorDxUiSdkRoot>
    <RedMonitorDxUiSdkLease>@LEASE@</RedMonitorDxUiSdkLease><RedMonitorCiEngineRoot>@ENGINE@</RedMonitorCiEngineRoot>
    <Configuration>Release</Configuration><Platform>@PLATFORM@</Platform><VCToolsVersion>@COMPILER@</VCToolsVersion>
    <EnableASAN Condition="'$(SdkFixtureCase)'=='global-asan'">true</EnableASAN>
  </PropertyGroup>
  <Import Project="@PROPS@" />
  <ItemGroup>
    <ClCompile Include="fixture.cpp">
      <RuntimeLibrary Condition="'$(SdkFixtureCase)'=='crt'">MultiThreaded</RuntimeLibrary>
      <LanguageStandard Condition="'$(SdkFixtureCase)'=='language'">stdcpp20</LanguageStandard>
      <EnableASAN Condition="'$(SdkFixtureCase)'=='file-asan'">true</EnableASAN>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='debug'">_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='stl'">_DISABLE_STL_ANNOTATION;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='vector'">_DISABLE_VECTOR_ANNOTATION;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='string'">_DISABLE_STRING_ANNOTATION;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='iterator'">_ITERATOR_DEBUG_LEVEL=1;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='secure-scl'">_SECURE_SCL=1;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='iterator-debugging'">_HAS_ITERATOR_DEBUGGING=1;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <StructMemberAlignment Condition="'$(SdkFixtureCase)'=='packing'">1Byte</StructMemberAlignment>
      <TreatWChar_tAsBuiltInType Condition="'$(SdkFixtureCase)'=='wchar'">false</TreatWChar_tAsBuiltInType>
      <CallingConvention Condition="'$(SdkFixtureCase)'=='calling-convention'">StdCall</CallingConvention>
      <PreprocessorDefinitions Condition="'$(SdkFixtureCase)'=='missing-ndebug'">UNICODE;_UNICODE</PreprocessorDefinitions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-crt'">/MT %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-language'">/std:c++20 %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-annotation'">/D_DISABLE_STL_ANNOTATION %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-iterator'">/D_ITERATOR_DEBUG_LEVEL=1 %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-quoted-iterator'">/D &quot;_ITERATOR_DEBUG_LEVEL=1&quot; %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-undefine'">/U NDEBUG %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-packing'">/Zp1 %(AdditionalOptions)</AdditionalOptions>
      <AdditionalOptions Condition="'$(SdkFixtureCase)'=='opaque-wchar'">/Zc:wchar_t- %(AdditionalOptions)</AdditionalOptions>
    </ClCompile>
  </ItemGroup>
</Project>
'@
    $values=@{ROOT=($root.TrimEnd('\','/')+'\');SDK=$sdk.SdkRoot;LEASE=$sdk.LeasePath;ENGINE=$engine;PLATFORM=$Platform;
        COMPILER=$manifest.compiler.vcToolsVersion;PROPS=(Join-Path $root 'Build/RedMonitor.DxUi.props')}
    foreach($key in $values.Keys){$xml=$xml.Replace('@'+$key+'@',[Security.SecurityElement]::Escape($values[$key]))}
    $project=Join-Path $run 'SdkAdmission.proj'
    [IO.File]::WriteAllText($project,$xml,[Text.UTF8Encoding]::new($false))
    $msbuild=Get-RedMonitorMSBuild
    $rows=[Collections.Generic.List[object]]::new()
    foreach($case in @('valid','crt','language','global-asan','file-asan','debug','stl','vector','string','iterator','secure-scl','iterator-debugging','packing','wchar','calling-convention','missing-ndebug','opaque-crt','opaque-language','opaque-annotation','opaque-iterator','opaque-quoted-iterator','opaque-undefine','opaque-packing','opaque-wchar')){
        $log=Join-Path $run ($case+'.log')
        & $msbuild $project /nologo /v:minimal '/t:ValidateDxUiSdkProfile;RedMonitorValidateSdkConsumer' ("/p:SdkFixtureCase="+$case) *> $log
        $exit=$LASTEXITCODE;$text=[IO.File]::ReadAllText($log)
        $passed=if($case -ceq 'valid'){$exit -eq 0}else{$exit -ne 0 -and $text -match 'Pinned SDK v1|Opaque compiler options'}
        $rows.Add([ordered]@{case=$case;exitCode=$exit;passed=$passed})
        if(-not $passed){throw "SDK MSBuild profile control failed: $case. Preserve $log"}
    }
    Close-CiPinnedSdkInput $sdk
    $closedLog=Join-Path $run 'closed-reader.log'
    & $msbuild $project /nologo /v:minimal '/t:RedMonitorValidateSdkConsumer' /p:SdkFixtureCase=valid *> $closedLog
    if($LASTEXITCODE -eq 0 -or [IO.File]::ReadAllText($closedLog) -notmatch 'reader lease is closed'){throw 'Stale direct MSBuild settings were not refused by the actual target.'}
    $rows.Add([ordered]@{case='closed-reader';exitCode=$LASTEXITCODE;passed=$true})
    [ordered]@{schemaVersion=1;role='SdkConsumerPolicyControls';passed=$true;sourceIdentity=(Get-RedMonitorSourceIdentity);
        dependency=$sdk.Evidence;cases=$rows.ToArray();runtimeQualified=$false}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $run 'receipt.json')
    Write-Host "PASS $($rows.Count) actual MSBuild SDK admission controls: $run"
}catch{$primary=$_;throw}
finally{
    if(-not $sdk.Closed){try{Close-CiPinnedSdkInput $sdk}catch{if($null -eq $primary){throw}else{Write-Warning ('SDK control close also failed: '+$_.Exception.Message)}}}
}
# Expected nonzero MSBuild controls must not leak a stale native exit status after verified success.
$global:LASTEXITCODE=0
