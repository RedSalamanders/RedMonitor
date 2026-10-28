#Requires -Version 7.0
# RedMonitor's local skill headers use only single-line name/description scalars. This deliberately
# bounded grammar avoids a Python/YAML dependency; unsupported metadata must fail rather than be ignored.
Set-StrictMode -Version Latest

function Assert-RedMonitorOrdinaryGuidancePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        $attributes = $null
        try { $attributes = [IO.File]::GetAttributes($current) }
        catch [IO.FileNotFoundException] { }
        catch [IO.DirectoryNotFoundException] { }
        if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Guidance path contains a reparse point: $current"
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function Get-RedMonitorSkillProblem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FolderName, [AllowNull()][AllowEmptyString()][string]$Text)
    if (-not $Text) { return 'missing or empty SKILL.md' }
    $match = [regex]::Match($Text.Replace("`r`n", "`n"), '\A---\n(?<header>.*?)\n---(?:\n|$)(?<body>[\s\S]*)\z', 'Singleline')
    if (-not $match.Success) { return 'missing frontmatter delimiters' }
    $values = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($line in $match.Groups['header'].Value -split "`n") {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $entry = [regex]::Match($line, '^(?<key>name|description):[ ]+(?<value>.+?) *$')
        if (-not $entry.Success) { return 'unsupported header; use single-line name and description scalars' }
        $key = $entry.Groups['key'].Value
        if ($values.ContainsKey($key)) { return "duplicate header key: $key" }
        $value = $entry.Groups['value'].Value
        if ($value.StartsWith("'")) {
            $quoted = [regex]::Match($value, "^'(?<text>(?:[^']|'')*)'$" )
            if (-not $quoted.Success) { return 'invalid quoted scalar' }
            $value = $quoted.Groups['text'].Value.Replace("''", "'")
        } elseif ($value.StartsWith('"')) {
            try {
                # Decode a JSON string without ConvertFrom-Json's automatic ISO-date coercion.
                $document = [Text.Json.JsonDocument]::Parse($value)
                try { $value = $document.RootElement.GetString() }
                finally { $document.Dispose() }
            }
            catch [System.ArgumentException] { return 'invalid quoted scalar' }
            catch [System.Management.Automation.RuntimeException] { return 'invalid quoted scalar' }
            if ($value -isnot [string]) { return 'header values must be strings' }
        } elseif ($value -match '^[-?:,\[\]{}#&*!|>''"%@`]' -or $value.Contains(': ') -or $value.EndsWith(':') -or
            $value -cmatch '^(?:~|null|Null|NULL|true|True|TRUE|false|False|FALSE|yes|Yes|YES|no|No|NO|on|On|ON|off|Off|OFF|=|<<)$' -or
            $value -cmatch '^[-+]?(?:[0-9][0-9_:]*(?:\.[0-9_]*)?(?:[eE][-+]?[0-9]+)?|\.[0-9_]+(?:[eE][-+]?[0-9]+)?|0[bB][01_]+|0[xX][0-9a-fA-F_]+|\.(?:inf|Inf|INF|nan|NaN|NAN))$' -or
            $value -cmatch '^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}(?:[Tt]|[ \t]+)[0-9]{1,2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]*)?(?:[ \t]*(?:Z|[-+][0-9]{1,2}(?::[0-9]{2})?))?)$' -or $value.Contains(' #')) {
            return 'unsupported plain scalar; quote the value'
        }
        $values.Add($key, $value)
    }
    if (-not $values.ContainsKey('name') -or $values['name'] -cne $FolderName -or
        $FolderName.Length -gt 64 -or $FolderName -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        return 'name must match the lowercase hyphenated skill folder'
    }
    if (-not $values.ContainsKey('description') -or -not $values['description'].Trim() -or
        $values['description'].Length -gt 1024 -or $values['description'] -match '[<>]' -or
        $values['description'].TrimStart().StartsWith('[TODO:')) { return 'invalid or unfinished description' }
    if (-not $match.Groups['body'].Value.Trim()) { return 'empty skill instructions' }
    return $null
}

function Get-RedMonitorMarkdownLinkAnalysis {
    param([Parameter(Mandatory)][string]$Text)
    $fence = $null
    $prose = [Collections.Generic.List[string]]::new()
    foreach ($line in $Text -split "`r?`n") {
        $marker = [regex]::Match($line, '^ {0,3}(?:(?:[-+*]|\d+[.)])[ \t]+)?(?<fence>`{3,}|~{3,})(?<rest>.*)$')
        # Backtick fence info cannot contain backticks; a same-line code span is prose.
        if ($marker.Success -and ($null -ne $fence -or $marker.Groups['fence'].Value[0] -cne '`' -or
            -not $marker.Groups['rest'].Value.Contains('`'))) {
            $token = $marker.Groups['fence'].Value
            if ($null -eq $fence) { $fence = $token }
            elseif ($token[0] -ceq $fence[0] -and $token.Length -ge $fence.Length -and -not $marker.Groups['rest'].Value.Trim()) { $fence = $null }
        } elseif ($null -eq $fence) { $prose.Add($line) }
    }
    # Equal-length backtick runs delimit inline code; a pseudo-link in code is not a destination.
    # Blank paragraphs end this bounded inline-code span rather than hiding later real links.
    $text = [regex]::Replace(($prose -join "`n"), '(?<![\\`])(`+)(?!`)(?:(?!\r?\n[ \t]*\r?\n)[\s\S])*?(?<!`)\1(?!`)', ' ')
    # Balancing groups preserve nested parentheses in inline and reference-style destinations.
    $destination = '(?:<(?<angle>[^>\r\n]*)>|(?<plain>(?:\\[()]|\\(?![()])|[^()\s\\]|\((?<depth>)|\)(?<-depth>))+(?(depth)(?!))))'
    $title = '(?:[ \t]+(?:"[^"\r\n]*"|''[^''\r\n]*''|\([^()\r\n]*\)))?[ \t]*'
    $labelStart = '(?<!\\)(?:\\\\)*\[' # Only an even number of preceding backslashes leaves a live bracket.
    $inline = $labelStart+'[^\]\r\n]*\]\([ \t]*'+$destination+$title+'\)'
    $declared = [Collections.Generic.List[string]]::new()
    $occurrences = [Collections.Generic.List[string]]::new()
    foreach ($link in [regex]::Matches($text,$inline)) {
        $target = if ($link.Groups['angle'].Success) { $link.Groups['angle'].Value } else { $link.Groups['plain'].Value }
        if ($target) { $declared.Add(($target -replace '\\([()])','$1')) }
    }
    $definitions = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    $definitionPattern = '(?m)^[ ]{0,3}\[(?<label>[^\]\r\n]+)\]:[ \t]*(?:\r?\n[ \t]*)?'+$destination+$title+'$'
    foreach ($link in [regex]::Matches($text,$definitionPattern)) {
        $label = [regex]::Replace($link.Groups['label'].Value.Trim(),'\s+',' ')
        if ($definitions.ContainsKey($label)) { continue } # CommonMark uses the first definition.
        $target = if ($link.Groups['angle'].Success) { $link.Groups['angle'].Value } else { $link.Groups['plain'].Value }
        $definitions.Add($label,($target -replace '\\([()])','$1'))
        if ($target) { $declared.Add($definitions[$label]) }
    }
    # Declarations are checked even when unused, but only rendered uses count as plan-index links.
    # Mask complete definitions, including continued destinations, before counting rendered uses.
    # Full/collapsed references require adjacent brackets; separated shortcuts are distinct uses.
    $usageText = [regex]::Replace($text,$definitionPattern,' ')
    $usagePattern = '(?<inline>'+ $inline +')|(?<reference>'+$labelStart+'(?<text>[^\]\r\n]+)\]\[(?<label>[^\]\r\n]*)\])|'+$labelStart+'(?<shortcut>[^\]\r\n]+)\]'
    foreach ($usage in [regex]::Matches($usageText,$usagePattern)) {
        $target = $null
        if ($usage.Groups['inline'].Success) {
            $target = if ($usage.Groups['angle'].Success) { $usage.Groups['angle'].Value } else { $usage.Groups['plain'].Value }
            $target = $target -replace '\\([()])','$1'
        } elseif ($usage.Groups['reference'].Success) {
            $label = if ($usage.Groups['label'].Value) { $usage.Groups['label'].Value } else { $usage.Groups['text'].Value }
            $label = [regex]::Replace($label.Trim(),'\s+',' ')
            if (-not $definitions.ContainsKey($label)) { throw "Unresolved Markdown reference label: $label" }
            $target = $definitions[$label]
        } elseif ($usage.Groups['shortcut'].Success) {
            $label = [regex]::Replace($usage.Groups['shortcut'].Value.Trim(),'\s+',' ')
            if ($definitions.ContainsKey($label)) { $target = $definitions[$label] }
        }
        if ($target) { $occurrences.Add($target) }
    }
    return [pscustomobject]@{ DeclaredTargets=$declared.ToArray(); OccurrenceTargets=$occurrences.ToArray() }
}

function Get-RedMonitorDeclaredLink {
    param([Parameter(Mandatory)][string]$Text)
    return (Get-RedMonitorMarkdownLinkAnalysis $Text).DeclaredTargets
}

function Get-RedMonitorReferencePath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Document,
        [Parameter(Mandatory)][string]$Target)
    if ($Target -match '^#|^//') { return $null }
    $local = ($Target -split '[#?]',2)[0]
    if ($local.StartsWith('file:',[StringComparison]::OrdinalIgnoreCase)) {
        $uri = $null
        if (-not [uri]::TryCreate($local,[UriKind]::Absolute,[ref]$uri) -or -not $uri.IsFile) { throw "Invalid local file URI: $Target" }
        $local = $uri.LocalPath
    } elseif ($local -match '^[a-zA-Z]:(?![\\/])') { throw "Drive-relative guidance reference: $Target" }
    elseif ($local -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -and $local -notmatch '^[a-zA-Z]:[\\/]') { return $null }
    else { $local = [uri]::UnescapeDataString($local) }
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine((Split-Path $Document),$local))
    if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not $path.Equals($prefix.TrimEnd('\','/'), [StringComparison]::OrdinalIgnoreCase)) { throw "non-repository reference: $Target" }
    Assert-RedMonitorOrdinaryGuidancePath $path
    if (-not (Test-Path -LiteralPath $path)) { throw "missing local reference: $Target" }
    return $path
}

function Get-RedMonitorMarkdownProblem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Document)
    try {
        Assert-RedMonitorOrdinaryGuidancePath $Document
        $text = [IO.File]::ReadAllText($Document,[Text.UTF8Encoding]::new($false,$true))
        foreach ($target in Get-RedMonitorDeclaredLink $text) {
            try { [void](Get-RedMonitorReferencePath -Root $Root -Document $Document -Target $target) }
            catch { $_.Exception.Message }
        }
    } catch { $_.Exception.Message }
}

function Get-RedMonitorPackageMarkdown {
    param([Parameter(Mandatory)][string]$Root)
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($Root)
    while ($pending.Count) {
        $directory = $pending.Pop()
        Assert-RedMonitorOrdinaryGuidancePath $directory
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
            Assert-RedMonitorOrdinaryGuidancePath $entry.FullName
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
            elseif ($entry.Extension -ieq '.md') { $entry.FullName }
        }
    }
}

function Test-RedMonitorAgentGuidance {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)
    $failures = [Collections.Generic.List[string]]::new()
    $skillRoot = Join-Path $Root '.agents/skills'
    Assert-RedMonitorOrdinaryGuidancePath $skillRoot
    $folders = @(Get-ChildItem -LiteralPath $skillRoot -Directory -Force -ErrorAction Stop)
    if (-not $folders.Count) { $failures.Add('No repository skills found') }
    foreach ($folder in $folders) {
        if ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { $failures.Add("Reparse skill folder: $($folder.Name)"); continue }
        $path = Join-Path $folder.FullName 'SKILL.md'
        try { Assert-RedMonitorOrdinaryGuidancePath $path }
        catch { $failures.Add($_.Exception.Message); continue }
        $text = if ([IO.File]::Exists($path)) { [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false,$true)) } else { $null }
        $problem = Get-RedMonitorSkillProblem -FolderName $folder.Name -Text $text
        if ($problem) { $failures.Add("$($folder.Name): $problem"); continue }
        try { foreach ($file in Get-RedMonitorPackageMarkdown $folder.FullName) {
            foreach ($problem in Get-RedMonitorMarkdownProblem -Root $Root -Document $file) { $failures.Add("$($folder.Name): $problem") }
        } } catch { $failures.Add($_.Exception.Message) }
    }
    $wip = Join-Path $Root 'Specs/Plans/WIP'
    $index = Join-Path $wip 'README.md'
    Assert-RedMonitorOrdinaryGuidancePath $index
    if (-not [IO.File]::Exists($index)) { $failures.Add('Missing active-plan index') }
    else {
        $links = Get-RedMonitorMarkdownLinkAnalysis ([IO.File]::ReadAllText($index))
        foreach ($target in $links.DeclaredTargets) {
            try { [void](Get-RedMonitorReferencePath -Root $Root -Document $index -Target $target) }
            catch { $failures.Add("Active-plan index: $($_.Exception.Message)") }
        }
        $indexed = [Collections.Generic.List[string]]::new()
        foreach ($target in $links.OccurrenceTargets) {
            try {
                $resolved = Get-RedMonitorReferencePath -Root $Root -Document $index -Target $target
                if ($resolved) { $indexed.Add($resolved) }
            } catch { $failures.Add("Active-plan index: $($_.Exception.Message)") }
        }
        foreach ($plan in Get-ChildItem -LiteralPath $wip -File -Filter '*.md' | Where-Object Name -ne 'README.md') {
            $matches = @($indexed | Where-Object { $_ -ieq $plan.FullName })
            if ($matches.Count -ne 1) { $failures.Add("Active plan must have exactly one index link: $($plan.Name)") }
        }
    }
    if ($failures.Count) { throw ($failures -join "`n") }
    Write-Host "Skill structure, declared local references and active-plan index: PASS ($($folders.Count) skills)."
    Write-Host 'Instruction quality, command execution and native behavior: NOT_EVALUATED.'
}

Export-ModuleMember -Function Get-RedMonitorSkillProblem, Test-RedMonitorAgentGuidance, Get-RedMonitorMarkdownProblem, Assert-RedMonitorOrdinaryGuidancePath
