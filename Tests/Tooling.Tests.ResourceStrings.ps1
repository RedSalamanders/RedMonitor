<#
.SYNOPSIS
Checks the viewer's STRINGTABLE resources without native compilation: positional placeholders only, no printf
tokens, every id defined and every id the viewer source uses present, and satellites that match the base strings.
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'src'
$checks=0
$violations=[Collections.Generic.List[string]]::new()
function Require([bool]$Condition,[string]$Message){
    if(-not $Condition){$script:violations.Add($Message)}
    $script:checks++
}
function Get-StringEntries([string]$Path){
    $entries=[Collections.Generic.List[object]]::new()
    $lines=[IO.File]::ReadAllLines($Path,[Text.UTF8Encoding]::new($false))
    $inTable=$false;$inBlock=$false
    for($index=0;$index -lt $lines.Count;$index++){
        $line=$lines[$index].Trim()
        if(-not $inTable){if($line -ceq 'STRINGTABLE'){$inTable=$true};continue}
        if(-not $inBlock){if($line -ceq 'BEGIN' -or $line -ceq '{'){$inBlock=$true};continue}
        if($line -ceq 'END' -or $line -ceq '}'){$inTable=$false;$inBlock=$false;continue}
        if($line -eq '' -or $line.StartsWith('//')){continue}
        $match=[regex]::Match($line,'^(?<id>[A-Za-z_][A-Za-z0-9_]*)\s*,?\s*"(?<text>(?:[^"]|"")*)"\s*$')
        if(-not $match.Success){$script:violations.Add("${Path}:$($index+1) is not a one-line STRINGTABLE entry: $line");continue}
        $entries.Add([pscustomobject]@{Id=$match.Groups['id'].Value;Text=$match.Groups['text'].Value.Replace('""','"');Path=$Path;Line=$index+1})
    }
    return ,$entries
}
function Get-Placeholders([string]$Text){
    $found=[Collections.Generic.List[object]]::new()
    foreach($match in [regex]::Matches($Text,'(?<!\{)\{([^{}]*)\}(?!\})')){
        $body=$match.Groups[1].Value
        $indexed=[regex]::Match($body,'^(?<index>\d+)(?::[^}]*)?$')
        $found.Add([pscustomobject]@{Token=$match.Value;Index=if($indexed.Success){[int]$indexed.Groups['index'].Value}else{$null}})
    }
    return ,$found
}
function Get-Signature($Placeholders){
    return (@($Placeholders|Where-Object {$null -ne $_.Index}|ForEach-Object Token|Sort-Object -Unique) -join '|')
}

$defined=@{}
foreach($match in [regex]::Matches([IO.File]::ReadAllText((Join-Path $source 'resource.h')),'(?m)^\s*#define\s+(?<id>[A-Za-z_][A-Za-z0-9_]*)\s+(?<value>\d+)')){
    $defined[$match.Groups['id'].Value]=[int]$match.Groups['value'].Value
}
$base=Get-StringEntries (Join-Path $source 'RedMonitor.rc')
Require ($base.Count -gt 0) 'src/RedMonitor.rc has no STRINGTABLE entries.'
$baseById=@{}
foreach($entry in $base){
    Require (-not $baseById.ContainsKey($entry.Id)) "$($entry.Path):$($entry.Line) repeats $($entry.Id)."
    $baseById[$entry.Id]=$entry
}
$satellites=@(Get-ChildItem -LiteralPath (Join-Path $source 'Lang') -Recurse -Filter '*.rc' -File|Sort-Object FullName)
Require ($satellites.Count -ge 1) 'No satellite resource files were found under src/Lang.'
$all=[Collections.Generic.List[object]]::new();$all.AddRange($base)
foreach($satellite in $satellites){
    $entries=Get-StringEntries $satellite.FullName
    $seen=@{}
    foreach($entry in $entries){
        Require (-not $seen.ContainsKey($entry.Id)) "$($entry.Path):$($entry.Line) repeats $($entry.Id)."
        $seen[$entry.Id]=$true
        Require ($baseById.ContainsKey($entry.Id)) "$($entry.Path):$($entry.Line) $($entry.Id) has no base string."
        if($baseById.ContainsKey($entry.Id)){
            $want=Get-Signature (Get-Placeholders $baseById[$entry.Id].Text)
            $have=Get-Signature (Get-Placeholders $entry.Text)
            Require ($want -ceq $have) "$($entry.Path):$($entry.Line) $($entry.Id) placeholders [$have] differ from the base [$want]."
        }
    }
    $all.AddRange($entries)
}
foreach($entry in $all){
    Require ($defined.ContainsKey($entry.Id)) "$($entry.Path):$($entry.Line) $($entry.Id) is not defined in src/resource.h."
    $placeholders=Get-Placeholders $entry.Text
    foreach($placeholder in $placeholders|Where-Object {$null -eq $_.Index}){
        Require $false "$($entry.Path):$($entry.Line) $($entry.Id) uses the non-positional placeholder $($placeholder.Token)."
    }
    $indexes=@($placeholders|Where-Object {$null -ne $_.Index}|ForEach-Object Index|Sort-Object -Unique)
    if($indexes.Count){
        Require (($indexes -join ',') -ceq ((0..($indexes.Count-1)) -join ',')) "$($entry.Path):$($entry.Line) $($entry.Id) skips a placeholder index ($($indexes -join ','))."
    }
    $printf=[regex]::Match($entry.Text,'%(?:[-+#0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|I64|I32|I)?[sSdiuxXfcC])')
    Require (-not $printf.Success) "$($entry.Path):$($entry.Line) $($entry.Id) uses the printf token $($printf.Value)."
}
foreach($file in Get-ChildItem -LiteralPath $source -File|Where-Object {$_.Extension -in '.cpp','.h' -and $_.Name -ne 'resource.h'}){
    foreach($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName),'\bIDS_[A-Z0-9_]+\b')){
        Require ($baseById.ContainsKey($match.Value)) "src/$($file.Name) uses $($match.Value), which src/RedMonitor.rc does not define."
    }
}
if($violations.Count){throw "Resource string gate failed:`n$($violations -join "`n")"}
Write-Host "PASS: resource strings ($checks checks, $($base.Count) base strings, $($satellites.Count) satellites)"
