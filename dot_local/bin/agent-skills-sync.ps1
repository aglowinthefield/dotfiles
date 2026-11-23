# agent-skills-sync.ps1 - Windows twin of ~/.local/bin/agent-skills-sync.
#
# Clones each repo in $Repos to ~/code/<repo>, fast-forwards it while it sits on
# main, and links every skills\<skill>\ at ~/.agents/skills/<skill> and
# ~/.claude/skills/<skill>. Links are directory junctions, which need neither
# admin nor Developer Mode. A real folder already in the way is moved to
# %LOCALAPPDATA%\agent-skills-sync\replaced, never deleted.
#
# The "agent-skills-sync" scheduled task runs this hourly.

$ErrorActionPreference = 'Continue'

$Owner = 'aglowinthefield'
$Repos = @('skills', 'clearstack')

$Code = Join-Path $HOME 'code'
$Agents = Join-Path $HOME '.agents\skills'
$Claude = Join-Path $HOME '.claude\skills'
$State = Join-Path $env:LOCALAPPDATA 'agent-skills-sync'

function Log($msg) { Write-Output "agent-skills-sync: $msg" }

New-Item -ItemType Directory -Force -Path $State, $Agents | Out-Null

function Sync-Repo($name) {
    $dir = Join-Path $Code $name
    $ssh = "git@github.com:$Owner/$name.git"
    if (-not (Test-Path (Join-Path $dir '.git'))) {
        New-Item -ItemType Directory -Force -Path $Code | Out-Null
        git clone --quiet $ssh $dir
        if ($LASTEXITCODE -ne 0) { Log "could not clone $ssh"; return $false }
        Log "cloned $name"
        return $true
    }
    git -C $dir fetch --quiet origin main
    if ($LASTEXITCODE -ne 0) { Log "${name}: fetch failed"; return $true }
    $branch = git -C $dir symbolic-ref --short -q HEAD
    if ($branch -eq 'main') {
        git -C $dir merge --ff-only --quiet origin/main 2>$null
        if ($LASTEXITCODE -ne 0) { Log "${name}: main has local commits or edits in the way; left as is" }
    } else {
        Log "${name}: checkout is on '$branch', not main; fetched without updating it"
    }
    return $true
}

function Set-Link($target, $path) {
    $item = Get-Item -LiteralPath $path -Force -EA SilentlyContinue
    if ($item) {
        if ($item.LinkType) {
            if ($item.Target -contains $target) { return }
            $item.Delete()
        } else {
            New-Item -ItemType Directory -Force -Path (Join-Path $State 'replaced') | Out-Null
            $moved = Join-Path $State ("replaced\{0}.{1}" -f $item.Name, (Get-Date -Format 'yyyyMMddHHmmss'))
            Move-Item -LiteralPath $path -Destination $moved
            Log "moved the old $path to $moved"
        }
    }
    New-Item -ItemType Junction -Path $path -Target $target | Out-Null
}

foreach ($repo in $Repos) {
    if (-not (Sync-Repo $repo)) { continue }
    Get-ChildItem -Directory (Join-Path $Code "$repo\skills") -EA SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
        ForEach-Object {
            Set-Link $_.FullName (Join-Path $Agents $_.Name)
            if (Test-Path (Join-Path $HOME '.claude')) {
                New-Item -ItemType Directory -Force -Path $Claude | Out-Null
                Set-Link $_.FullName (Join-Path $Claude $_.Name)
            }
        }
}

# Drop links to skills a repo no longer has (removed or renamed upstream).
foreach ($dir in @($Agents, $Claude)) {
    Get-ChildItem -LiteralPath $dir -Force -EA SilentlyContinue | Where-Object { $_.LinkType } | ForEach-Object {
        $t = @($_.Target)[0]
        foreach ($repo in $Repos) {
            if ($t -like (Join-Path $Code "$repo\skills\*") -and -not (Test-Path -LiteralPath $t)) {
                $_.Delete()
                Log "removed $($_.FullName); $repo no longer has it"
            }
        }
    }
}
