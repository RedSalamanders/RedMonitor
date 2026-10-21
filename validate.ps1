<#
.SYNOPSIS
Validates standalone source, documentation, dependency pins and script syntax without mutation.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$failures=[Collections.Generic.List[string]]::new()
$required=@('AGENTS.md','LICENSE.txt','README.md','capabilities.json','Specs/README.md','Specs/Plans/WIP/README.md',
 'Specs/Plans/WIP/RedMonitorExtraction_2026-10-21.md','Specs/SourceImport/source-origin.json','src/RedMonitor.vcxproj',
 'Tests/MonitorTest.vcxproj','Build/Toolchain.psm1','Dependencies/DxUi.lock.json','vcpkg.json','vcpkg-tool.json')
foreach($path in $required){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $path) -PathType Leaf)){$failures.Add("Missing $path")}}
$files=@(Get-ChildItem -LiteralPath $PSScriptRoot -File -Force)
foreach($dir in Get-ChildItem -LiteralPath $PSScriptRoot -Directory -Force|Where-Object Name -notin '.git','.build','.vs'){
    $files+=@(Get-ChildItem -LiteralPath $dir.FullName -File -Recurse)
}
foreach($file in $files|Where-Object Extension -in '.ps1','.psm1'){
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach($error in $errors){$failures.Add("$($file.FullName): $error")}
}
foreach($path in 'Dependencies/DxUi.lock.json','vcpkg-tool.json'){
    $pin=Get-Content -LiteralPath (Join-Path $PSScriptRoot $path) -Raw|ConvertFrom-Json
    if($pin.commit -cnotmatch '^[0-9a-f]{40}$'){$failures.Add("Invalid exact pin: $path")}
}
foreach($file in $files|Where-Object Extension -eq '.md'|Where-Object FullName -notmatch '[\\/]Themes[\\/]'){
    foreach($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName),'\]\(([^)]+)\)')){
        $target=$match.Groups[1].Value.Split('#')[0]
        if(-not $target -or $target -match '^[a-zA-Z]+:|^/' -or $target -match '\$') {continue}
        $resolved=Join-Path $file.DirectoryName $target
        if(-not(Test-Path -LiteralPath $resolved)){$failures.Add("Broken link $target in $($file.FullName)")}
    }
}
foreach($file in $files|Where-Object Extension -in '.vcxproj','.props','.targets'){
    $content=[IO.File]::ReadAllText($file.FullName)
    if($content -match '(?i)[A-Z]:[\\/]src[\\/]|\.\.\W+RedSalamander[\\/]|Common\.vcxproj'){$failures.Add("Sibling dependency in $($file.FullName)")}
    try{$null=[xml]$content}catch{$failures.Add("Invalid XML: $($file.FullName)")}
}
foreach($skill in Get-ChildItem (Join-Path $PSScriptRoot '.agents/skills') -Filter SKILL.md -Recurse){
    if([IO.File]::ReadAllText($skill.FullName) -notmatch '(?s)^---\r?\nname: [a-z0-9-]+\r?\ndescription: [^\r\n]+\r?\n---'){$failures.Add("Invalid skill: $($skill.FullName)")}
}
if($failures.Count){foreach($failure in $failures){Write-Host $failure -ForegroundColor Red};throw "$($failures.Count) validation failures"}
Write-Host "Validated $($files.Count) source/documentation/tool files."
