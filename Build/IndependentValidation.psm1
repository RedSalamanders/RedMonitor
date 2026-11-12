# Local independent checks only: no native result, CI delegation or hosted adoption.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Toolchain.psm1')
Import-Module (Join-Path $PSScriptRoot 'AgentGuidance.psm1')
Import-Module (Join-Path $PSScriptRoot 'Formatting.psm1')

function Get-RedMonitorIndependentIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)
    $formatter=Get-RedMonitorClangFormat -Root $Root
    $git=(Get-Command git -CommandType Application|Select-Object -First 1).Source
    $hostPath=(Get-Process -Id $PID).Path
    $assembly=[System.Management.Automation.PSObject].Assembly.Location
    $tools=@(foreach($path in @($hostPath,$assembly,$git,$formatter)){
        Assert-RedMonitorOrdinaryGuidancePath $path
        [ordered]@{path=[IO.Path]::GetFullPath($path).ToLowerInvariant();sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash}
    })
    $environment=[ordered]@{powershell=$PSVersionTable.PSVersion.ToString();runtime=[Environment]::Version.ToString();os=[Environment]::OSVersion.VersionString;architecture=[Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()}
    foreach($name in @('PATH','PSModulePath','VSINSTALLDIR','VCToolsInstallDir','WindowsSdkDir','SystemRoot','COMSPEC','TEMP','TMP','CI','GITHUB_ACTIONS','CI_NATIVE_BUILDS_DISABLED','RUNNER_OS')){
        $environment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
    }
    $source=Get-RedMonitorSourceIdentity -Root $Root
    $projection=[ordered]@{schema=1;source=$source;tools=$tools;environment=$environment}
    $bytes=[Text.Encoding]::UTF8.GetBytes(($projection|ConvertTo-Json -Depth 8 -Compress))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Write-RedMonitorIndependentRecord {
    # This local writer differs from changelog publication: create-only attempt evidence plus
    # one replaceable latest-state index, both constrained by the existing .build ownership guard.
    param([string]$Path,[object]$Value,[switch]$Replace)
    $target=Assert-RedMonitorOutputPath $Path
    [void][IO.Directory]::CreateDirectory((Split-Path $target))
    $temporary=Assert-RedMonitorOutputPath ($target+'.'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{
        [IO.File]::WriteAllText($temporary,($Value|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary,$target,$Replace.IsPresent)
    }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
}

function Test-RedMonitorIndependentReceipt {
    param([string]$Directory,[string]$Scope,[string]$Identity)
    $latest=Assert-RedMonitorOutputPath (Join-Path $Directory 'latest.json')
    if(-not [IO.File]::Exists($latest)){return $false}
    try{
        if((Get-Item -LiteralPath $latest).Length -gt 4096){return $false}
        $index=Get-Content -LiteralPath $latest -Raw|ConvertFrom-Json
        if($index.schema -ne 1 -or $index.status -cne 'passed' -or $index.identity -cne $Identity -or $index.scope -cne $Scope -or $index.attempt -cnotmatch '^[a-f0-9]{32}\.json$'){return $false}
        $attempt=Assert-RedMonitorOutputPath (Join-Path $Directory $index.attempt)
        if(-not [IO.File]::Exists($attempt) -or (Get-Item -LiteralPath $attempt).Length -gt 4096){return $false}
        if((Get-FileHash -LiteralPath $attempt -Algorithm SHA256).Hash -cne $index.sha256){return $false}
        $record=Get-Content -LiteralPath $attempt -Raw|ConvertFrom-Json
        return ($record.schema -eq 1 -and $record.scope -ceq $Scope -and $record.status -ceq 'passed' -and $record.identity -ceq $Identity)
    }catch{return $false}
}

function Invoke-RedMonitorIndependentCheck {
    [CmdletBinding()]
    param([string]$Root,[ValidateSet('Validation','Format','Tooling')][string]$Scope,[scriptblock]$Action,[string]$OriginalIdentity,[switch]$Force)
    $before=Get-RedMonitorIndependentIdentity -Root $Root
    if($before -cne $OriginalIdentity){throw 'Inputs changed during independent validation; run again on the current tree.'}
    $directory=Assert-RedMonitorOutputPath (Join-Path $Root ('.build/validation-evidence/independent/'+$Scope))
    if(-not $Force -and (Test-RedMonitorIndependentReceipt $directory $Scope $before)){
        Write-Host "REUSED independent $Scope (exact local source/tools/environment)."
        return
    }
    $attempt=[guid]::NewGuid().ToString('N')+'.json'
    $index=[ordered]@{schema=1;scope=$Scope;identity=$before;status='started';attempt=$attempt;sha256=$null}
    # Revoke latest-state eligibility before execution. Interruption/failure cannot expose an older green.
    Write-RedMonitorIndependentRecord (Join-Path $directory 'latest.json') $index -Replace
    $status='failed'
    try{
        & $Action
        if((Get-RedMonitorIndependentIdentity -Root $Root) -cne $before){throw 'Inputs changed during independent validation; run again on the current tree.'}
        $status='passed'
    }finally{
        $path=Join-Path $directory $attempt
        $record=[ordered]@{schema=1;scope=$Scope;identity=$before;status=$status;completedUtc=[datetime]::UtcNow.ToString('o')}
        Write-RedMonitorIndependentRecord $path $record
        $index.status=$status;$index.sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        Write-RedMonitorIndependentRecord (Join-Path $directory 'latest.json') $index -Replace
    }
}

Export-ModuleMember -Function Get-RedMonitorIndependentIdentity,Invoke-RedMonitorIndependentCheck
