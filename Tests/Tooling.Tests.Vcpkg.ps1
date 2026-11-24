<#
.SYNOPSIS
Checks that both vcpkg restores keep a complete vcpkg checkout, with an owned offline Git fixture and no native work.
.DESCRIPTION
vcpkg extracts versioned ports with git read-tree and checkout-index in an environment that holds only
GIT_INDEX_FILE, so it can never fetch an object a partial clone left on the server. A file:// fixture repository
stands in for microsoft/vcpkg. Build/VcpkgToolCheckout.psm1, which prepares the pinned DxUi installer's checkout,
runs for real: fresh, repeated, completing the partial shallow checkout earlier installers left, and refusing a
foreign origin. Each prepared checkout then extracts an older tree in that stripped environment with lazy fetch
disabled, as vcpkg does. The engine checkout runs against the same offline registry. Both installer call paths are checked. The run is retained below
.build/vcpkg-tooling-tests.
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Build/Toolchain.psm1') -Force
Import-Module (Join-Path $root 'Build/VcpkgToolCheckout.psm1') -Force
$run=Assert-RedMonitorOutputPath (Join-Path $root ('.build/vcpkg-tooling-tests/'+[guid]::NewGuid().ToString('N')))
[void][IO.Directory]::CreateDirectory($run)
$checks=0
function Require([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    $script:checks++
}
function Refuses([scriptblock]$Body,[string]$Pattern){
    $failed=$false
    try{& $Body}catch{if($_.Exception.Message -notmatch $Pattern){throw};$failed=$true}
    Require $failed "Expected refusal: $Pattern"
}
function Git([string]$Directory,[string[]]$CommandArguments){
    $output=& git.exe -c core.autocrlf=false -C $Directory @CommandArguments
    if($LASTEXITCODE -ne 0){throw "Fixture Git failed: $($CommandArguments -join ' ')"}
    $output
}
# vcpkg's run_cmd_git_with_index: the child environment holds only GIT_INDEX_FILE. Lazy fetch is disabled too, so a
# file:// promisor cannot hide a missing object the way a reachable network would.
function Test-StrippedExtraction([string]$Checkout,[string]$Tree,[string]$Name){
    $target=Join-Path $run "extract-$Name"
    [void][IO.Directory]::CreateDirectory($target)
    $git=(Get-Command git.exe).Source
    foreach($commandArguments in @(@('read-tree',$Tree),@('--work-tree',$target,'checkout-index','-af',"--prefix=$target/"))){
        $start=[Diagnostics.ProcessStartInfo]::new($git)
        foreach($value in @('--git-dir',(Join-Path $Checkout '.git'),'-c','core.autocrlf=false')+$commandArguments){$start.ArgumentList.Add($value)}
        $start.UseShellExecute=$false
        $start.RedirectStandardOutput=$true
        $start.RedirectStandardError=$true
        $start.Environment.Clear()
        $start.Environment['GIT_INDEX_FILE']=Join-Path $run "extract-$Name.index"
        $start.Environment['GIT_NO_LAZY_FETCH']='1'
        $process=[Diagnostics.Process]::Start($start)
        try{
            $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
            $process.WaitForExit();[void]$stdout.Result;[void]$stderr.Result
            if($process.ExitCode -ne 0){return $false}
        }finally{$process.Dispose()}
    }
    return @(Get-ChildItem -LiteralPath $target -File).Count -eq 3
}
function Test-Prepared([string]$Checkout){
    (Git $Checkout @('remote','get-url','origin')) -ceq $url -and
        @(Git $Checkout @('status','--porcelain')).Count -eq 0 -and
        (Git $Checkout @('rev-parse','HEAD')) -ceq $pinned -and
        (Git $Checkout @('rev-parse','--is-shallow-repository')) -ceq 'false' -and
        -not (& git.exe -C $Checkout config --get remote.origin.partialclonefilter)
}

# A registry whose older tree shares no blob with the default branch or the pinned commit.
$registry=Join-Path $run 'registry'
[void][IO.Directory]::CreateDirectory($registry)
Git $registry @('init','-q','-b','master')|Out-Null
Git $registry @('config','uploadpack.allowFilter','true')|Out-Null
Git $registry @('config','uploadpack.allowAnySHA1InWant','true')|Out-Null
foreach($index in 1..5){
    [IO.File]::WriteAllText((Join-Path $registry "port$index.cmake"),"version $index")
    [IO.File]::WriteAllText((Join-Path $registry 'shared.cmake'),"revision $index")
    Git $registry @('add','-A')|Out-Null
    Git $registry @('-c','user.name=fixture','-c','user.email=fixture@invalid','commit','-q','-m',"registry $index")|Out-Null
}
$pinned=Git $registry @('rev-parse','HEAD~2')
$olderTree=Git $registry @('rev-parse','HEAD~3^{tree}')
$url='file:///'+$registry.Replace('\','/')
$identity=Join-Path $run 'vcpkg-tool.json'
[IO.File]::WriteAllText($identity,(@{repository=$url;commit=$pinned}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))

$fresh=Join-Path $run 'fresh/vcpkg-tool'
Initialize-VcpkgToolCheckout -ToolIdentityPath $identity -ToolRoot $fresh
Require (Test-Prepared $fresh) 'A fresh checkout is not a clean, complete checkout of the pinned commit.'
Initialize-VcpkgToolCheckout -ToolIdentityPath $identity -ToolRoot $fresh
Require (Test-Prepared $fresh) 'Repeating the preparation changed the checkout.'
Require (Test-StrippedExtraction $fresh $olderTree 'fresh') 'A fresh checkout cannot extract an older tree offline.'

# What the pinned DxUi installer and earlier versions of vcpkg-install.ps1 leave: partial, shallow, at the pin.
$partial=Join-Path $run 'partial/vcpkg-tool'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $partial))
Git $run @('clone','-q','-c','core.longpaths=true','--filter=blob:none',$url,$partial)|Out-Null
Git $partial @('fetch','-q','--depth','1','origin',$pinned)|Out-Null
Git $partial @('checkout','-q','--detach',$pinned)|Out-Null
Require (-not (Test-StrippedExtraction $partial $olderTree 'partial-control')) 'The partial fixture already held the older tree; the control proves nothing.'
Initialize-VcpkgToolCheckout -ToolIdentityPath $identity -ToolRoot $partial
Require (Test-Prepared $partial) 'The partial checkout was not completed into a clean checkout of the pinned commit.'
Require (Test-StrippedExtraction $partial $olderTree 'completed') 'The completed checkout still cannot extract an older tree offline.'

$foreign=Join-Path $run 'foreign/vcpkg-tool'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $foreign))
Git $run @('clone','-q',$url,$foreign)|Out-Null
Git $foreign @('remote','set-url','origin','https://example.invalid/other')|Out-Null
Refuses {Initialize-VcpkgToolCheckout -ToolIdentityPath $identity -ToolRoot $foreign} 'does not use the pinned repository'
$plain=Join-Path $run 'plain/vcpkg-tool'
[void][IO.Directory]::CreateDirectory($plain)
Refuses {Initialize-VcpkgToolCheckout -ToolIdentityPath $identity -ToolRoot $plain} 'not a Git checkout'

# Run the application installer's pinned shared checkout against the same offline registry.
Import-Module (Join-Path $root '.ci-engine/Tools/Modules/Ci.EngineBinding.psm1') -ErrorAction Stop
Import-Module (Resolve-CiPinnedEngineModule -ProjectRoot $root -Name 'VcpkgCheckout.psm1') -Scope Local -ErrorAction Stop
$shared=Join-Path $run 'shared/vcpkg-tool'
Initialize-CiVcpkgCheckout -ProjectRoot $root -Path $shared -Repository $url -Commit $pinned
Require (Test-Prepared $shared) 'The shared checkout did not prepare the clean, complete pinned source.'
Initialize-CiVcpkgCheckout -ProjectRoot $root -Path $shared -Repository $url -Commit $pinned
Require (Test-Prepared $shared) 'The shared warm checkout changed the pinned source.'
Require (Test-StrippedExtraction $shared $olderTree 'shared') 'The shared checkout cannot extract an older tree offline.'

$installer=[IO.File]::ReadAllText((Join-Path $root 'vcpkg-install.ps1'))
$checkout=$installer.IndexOf('Initialize-CiVcpkgCheckout -ProjectRoot $repoRoot -Path $toolRoot -Repository $repository -Commit $commit',[StringComparison]::Ordinal)
$bootstrap=$installer.IndexOf('Initialize-CiVcpkgExecutable -ProjectRoot $repoRoot -ToolRoot $toolRoot',[StringComparison]::Ordinal)
$install=$installer.IndexOf('Get-CiVcpkgManifestInstallArguments -ProjectRoot $repoRoot',[StringComparison]::Ordinal)
Require ($checkout -ge 0 -and $bootstrap -gt $checkout -and $install -gt $bootstrap) 'The application installer must use pinned checkout, bootstrap and manifest helpers in order.'
$restore=[IO.File]::ReadAllText((Join-Path $root 'restore-dxui.ps1'))
$prepare=$restore.IndexOf("Initialize-VcpkgToolCheckout -ToolIdentityPath (Join-Path `$source 'vcpkg-tool.json') -ToolRoot (Join-Path `$output 'vcpkg-tool')",[StringComparison]::Ordinal)
$pinnedInstaller=$restore.IndexOf("& (Join-Path `$source 'vcpkg-install.ps1') -Platform `$Platform -OutputRoot `$output",[StringComparison]::Ordinal)
Require ($prepare -ge 0 -and $pinnedInstaller -gt $prepare) 'restore-dxui.ps1 must prepare the complete checkout before the pinned DxUi installer runs.'

# The module is shared text that Windows PowerShell 5.1 hosts may load.
$module=Join-Path $root 'Build/VcpkgToolCheckout.psm1'
$bytes=[IO.File]::ReadAllBytes($module)
Require (@($bytes|Where-Object{$_ -gt 127}).Count -eq 0) 'Build/VcpkgToolCheckout.psm1 must stay ASCII.'
$windowsPowerShell=Get-Command powershell.exe -ErrorAction SilentlyContinue
if($windowsPowerShell){
    $parse="`$errors=`$null;[void][Management.Automation.Language.Parser]::ParseFile('$($module.Replace("'","''"))',[ref]`$null,[ref]`$errors);if(`$errors){`$errors|ForEach-Object{`$_.Message};exit 1}"
    $output=@(& $windowsPowerShell.Source -NoProfile -NonInteractive -Command $parse)
    Require ($LASTEXITCODE -eq 0) "Windows PowerShell 5.1 does not parse Build/VcpkgToolCheckout.psm1: $($output -join '; ')"
}
$global:LASTEXITCODE=0
Write-Host "PASS $checks complete vcpkg checkout controls: $run"
