# sysupdate.ps1 - update all package managers, clean cruft, report disk health
#
# Usage:
#   sysupdate.ps1                 update + clean + report
#   sysupdate.ps1 -UpdateOnly     skip the cleanup pass
#   sysupdate.ps1 -CleanOnly      skip the update pass
#   sysupdate.ps1 -Quiet          no console colour (used by the scheduled task)
#
# Logs to $env:LOCALAPPDATA\sysupdate\logs\sysupdate-<date>.log, keeping 12 runs.

[CmdletBinding()]
param(
    [switch]$UpdateOnly,
    [switch]$CleanOnly,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

$LogDir = Join-Path $env:LOCALAPPDATA 'sysupdate\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir ("sysupdate-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'))

$script:Warnings = @()

function Write-Log($msg, $colour = 'Gray') {
    $msg | Out-File -FilePath $LogFile -Append -Encoding utf8
    if ($Quiet) { Write-Output $msg } else { Write-Host $msg -ForegroundColor $colour }
}

function Section($name) { Write-Log "`n==> $name" 'Green' }
function Warn($msg) { $script:Warnings += $msg; Write-Log "    ! $msg" 'Yellow' }
function Info($msg) { Write-Log "    $msg" 'Gray' }

function Invoke-Step($name, [scriptblock]$block) {
    Section $name
    try { & $block 2>&1 | ForEach-Object { Write-Log "    $_" } }
    catch { Warn "$name failed: $($_.Exception.Message)" }
}

function Get-FreeSpace {
    $d = @{}
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -EA SilentlyContinue |
        ForEach-Object { $d[$_.DeviceID] = $_.FreeSpace }
    $d
}

function Get-FolderSize($path) {
    if (-not (Test-Path $path)) { return 0 }
    (Get-ChildItem $path -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
}

$startFree = Get-FreeSpace
Write-Log "sysupdate  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 'Cyan'
Write-Log "log: $LogFile" 'DarkGray'

# ---------------------------------------------------------------- updates ---

if (-not $CleanOnly) {

    Invoke-Step "Scoop" {
        scoop update
        scoop update --all
    }

    Invoke-Step "Winget" {
        winget upgrade --all --include-unknown --silent `
            --accept-source-agreements --accept-package-agreements --disable-interactivity
    }

    Invoke-Step "Rust (rustup)" {
        if (Get-Command rustup -EA SilentlyContinue) { rustup update } else { Warn "rustup not found, skipping" }
    }

    Invoke-Step "uv" {
        if (Get-Command uv -EA SilentlyContinue) {
            uv self update
            uv tool upgrade --all
        } else { Warn "uv not found, skipping" }
    }

    Invoke-Step "npm (global packages)" {
        if (Get-Command npm -EA SilentlyContinue) { npm update -g } else { Warn "npm not found, skipping" }
    }

    Invoke-Step "GitHub CLI extensions" {
        if (Get-Command gh -EA SilentlyContinue) { gh extension upgrade --all } else { Warn "gh not found, skipping" }
    }

    Invoke-Step "Chezmoi" {
        if (Get-Command chezmoi -EA SilentlyContinue) {
            chezmoi update --apply=false
            $diff = chezmoi diff 2>$null
            if ($diff) { Warn "chezmoi has undeployed changes - run 'chezmoi apply' or 'chezmoi diff' to review" }
        } else { Warn "chezmoi not found, skipping" }
    }

    # Report-only: installing needs elevation and may force a reboot, so this
    # never installs unattended. It just tells you what is waiting.
    Section "Windows Update (check only)"
    try {
        $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
        $pending = $searcher.Search("IsInstalled=0 and IsHidden=0").Updates
        if ($pending.Count -eq 0) {
            Info "no pending updates"
        } else {
            Warn "$($pending.Count) pending Windows update(s) - install via Settings or 'winget upgrade'"
            foreach ($u in $pending) { Info "- $($u.Title)" }
        }
    } catch { Warn "could not query Windows Update: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------- cleanup ---

if (-not $UpdateOnly) {

    Invoke-Step "Scoop cleanup (stale versions)" { scoop cleanup * }

    Section "Scoop cache prune (>30 days)"
    $cache = Join-Path $env:USERPROFILE 'scoop\cache'
    $old = Get-ChildItem $cache -File -Force -EA SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
    if ($old) {
        $mb = ($old | Measure-Object Length -Sum).Sum / 1MB
        $old | Remove-Item -Force -EA SilentlyContinue
        Info ("removed {0} cached installers ({1:N0} MB)" -f $old.Count, $mb)
    } else { Info "nothing older than 30 days" }

    Section "Temp files (>7 days)"
    $freed = 0
    foreach ($t in @($env:TEMP, 'C:\Windows\Temp')) {
        $items = Get-ChildItem $t -Recurse -Force -EA SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
        $freed += ($items | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
        $items | Remove-Item -Recurse -Force -EA SilentlyContinue
    }
    Info ("freed ~{0:N0} MB (locked files skipped)" -f ($freed / 1MB))

    Invoke-Step "Package caches" {
        if (Get-Command uv -EA SilentlyContinue) { uv cache prune }
        if (Get-Command npm -EA SilentlyContinue) { npm cache verify }
    }

    Section "Recycle bin"
    $binSize = 0
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -EA SilentlyContinue | ForEach-Object {
        $binSize += Get-FolderSize (Join-Path $_.DeviceID '\$RECYCLE.BIN')
    }
    if ($binSize / 1GB -gt 1) {
        Clear-RecycleBin -Force -EA SilentlyContinue
        Info ("emptied ~{0:N1} GB" -f ($binSize / 1GB))
    } else {
        Info ("{0:N0} MB - under the 1 GB threshold, left alone" -f ($binSize / 1MB))
    }
}

# ----------------------------------------------------------------- report ---

Section "Disk"
$endFree = Get-FreeSpace
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -EA SilentlyContinue | ForEach-Object {
    $id = $_.DeviceID
    $pct = 100 * $_.FreeSpace / $_.Size
    $delta = ($endFree[$id] - $startFree[$id]) / 1GB
    $sign = if ($delta -ge 0) { '+' } else { '' }
    Info ("{0} {1,7:N1} GB free of {2,7:N1} GB  ({3,4:N1}%)  {4}{5:N2} GB this run" -f `
        $id, ($_.FreeSpace / 1GB), ($_.Size / 1GB), $pct, $sign, $delta)
    if ($pct -lt 10) { Warn "$id is under 10% free - see the disk hotspots below" }
}

# Point at the usual suspects when a drive is tight, rather than guessing.
if (($endFree.Keys | Where-Object { $_ -eq 'D:' }) -and
    ((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'").FreeSpace / 1GB) -lt 200) {
    Section "D: hotspots"
    Get-ChildItem 'D:\' -Directory -Force -EA SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{ GB = (Get-FolderSize $_.FullName) / 1GB; Name = $_.Name }
    } | Sort-Object GB -Descending | Select-Object -First 5 | ForEach-Object {
        Info ("{0,8:N1} GB  {1}" -f $_.GB, $_.Name)
    }
}

# ---------------------------------------------------------------- wrap up ---

Get-ChildItem $LogDir -Filter 'sysupdate-*.log' | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 12 | Remove-Item -Force -EA SilentlyContinue

if ($script:Warnings.Count) {
    Write-Log "`n$($script:Warnings.Count) thing(s) need attention:" 'Yellow'
    $script:Warnings | ForEach-Object { Write-Log "  - $_" 'Yellow' }
} else {
    Write-Log "`nAll done, nothing needs attention." 'Green'
}
Write-Log "log: $LogFile" 'DarkGray'
