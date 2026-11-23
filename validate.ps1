<#
.SYNOPSIS
Validates standalone source, documentation, dependency pins and script syntax without mutation.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Build/AgentGuidance.psm1') -Force
$failures=[Collections.Generic.List[string]]::new()
$required=@('AGENTS.md','LICENSE.txt','README.md','capabilities.json','Specs/README.md','Specs/Plans/WIP/README.md','Specs/Plans/Done/README.md',
 'Specs/SourceImport/source-origin.json','src/RedMonitor.vcxproj',
 'Tests/MonitorTest.vcxproj','Build/Toolchain.psm1','Dependencies/DxUi.lock.json','vcpkg.json','vcpkg-tool.json')
foreach($path in $required){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $path) -PathType Leaf)){$failures.Add("Missing $path")}}
$files=[Collections.Generic.List[IO.FileInfo]]::new()
$pending=[Collections.Generic.Stack[string]]::new()
$pending.Push($PSScriptRoot)
while($pending.Count){
    $directory=$pending.Pop()
    foreach($entry in Get-ChildItem -LiteralPath $directory -Force){
        if($entry.PSIsContainer -and $entry.Name -in '.git','.build','.vs'){continue}
        try{Assert-RedMonitorOrdinaryGuidancePath $entry.FullName}
        catch{$failures.Add($_.Exception.Message);continue}
        if($entry.PSIsContainer){$pending.Push($entry.FullName)}else{$files.Add($entry)}
    }
}
foreach($file in $files|Where-Object Extension -in '.ps1','.psm1'){
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach($error in $errors){$failures.Add("$($file.FullName): $error")}
}
foreach($path in 'Dependencies/DxUi.lock.json','vcpkg-tool.json'){
    Assert-RedMonitorOrdinaryGuidancePath (Join-Path $PSScriptRoot $path)
    $pin=Get-Content -LiteralPath (Join-Path $PSScriptRoot $path) -Raw|ConvertFrom-Json
    if($pin.commit -cnotmatch '^[0-9a-f]{40}$'){$failures.Add("Invalid exact pin: $path")}
}
foreach($file in $files|Where-Object Extension -eq '.md'|Where-Object FullName -notmatch '[\\/]Themes[\\/]'){
    foreach($problem in Get-RedMonitorMarkdownProblem -Root $PSScriptRoot -Document $file.FullName){$failures.Add("$($file.FullName): $problem")}
}
foreach($file in $files|Where-Object Extension -in '.vcxproj','.props','.targets'){
    $content=[IO.File]::ReadAllText($file.FullName)
    if($content -match '(?i)[A-Z]:[\\/]src[\\/]|\.\.\W+RedSalamander[\\/]|Common\.vcxproj'){$failures.Add("Sibling dependency in $($file.FullName)")}
    try{$null=[xml]$content}catch{$failures.Add("Invalid XML: $($file.FullName)")}
}
try { Test-RedMonitorAgentGuidance -Root $PSScriptRoot }
catch [System.Management.Automation.RuntimeException] { $failures.Add($_.Exception.Message) }
if($failures.Count){foreach($failure in $failures){Write-Host $failure -ForegroundColor Red};throw "$($failures.Count) validation failures"}
Write-Host "Validated $($files.Count) source/documentation/tool files."
