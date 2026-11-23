# Checks RedMonitor documentation outside the shared agent guidance contract.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Toolchain.psm1') -ErrorAction Stop

function Get-RedMonitorDeclaredLink {
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
    # Explicit references need a definition even when another link in the file already used that target.
    $usageText = [regex]::Replace($text,$definitionPattern,' ')
    $usagePattern = '(?<inline>'+ $inline +')|(?<reference>'+$labelStart+'(?<text>[^\]\r\n]+)\]\[(?<label>[^\]\r\n]*)\])|'+$labelStart+'(?<shortcut>[^\]\r\n]+)\]'
    foreach ($usage in [regex]::Matches($usageText,$usagePattern)) {
        if (-not $usage.Groups['reference'].Success) { continue }
        $label = if ($usage.Groups['label'].Value) { $usage.Groups['label'].Value } else { $usage.Groups['text'].Value }
        $label = [regex]::Replace($label.Trim(),'\s+',' ')
        if (-not $definitions.ContainsKey($label)) { throw "Unresolved Markdown reference label: $label" }
    }
    return $declared.ToArray()
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

Export-ModuleMember -Function Get-RedMonitorMarkdownProblem
