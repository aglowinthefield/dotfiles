# sysupdate.ps1 - update all package managers and tools
$ErrorActionPreference = "Continue"

function Section($name) {
    Write-Host "`n==> $name" -ForegroundColor Green
}

function Warn($msg) {
    Write-Host "    $msg" -ForegroundColor Yellow
}

Section "Scoop"
scoop update
scoop update --all
scoop cleanup --all

Section "Winget"
winget upgrade --all --accept-source-agreements --accept-package-agreements

Section "Rust (rustup)"
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup update
} else {
    Warn "rustup not found, skipping"
}

Section "npm (global packages)"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm update -g
} else {
    Warn "npm not found, skipping"
}

Section "pip"
if (Get-Command pip -ErrorAction SilentlyContinue) {
    pip install --upgrade pip
} else {
    Warn "pip not found, skipping"
}

Section "GitHub CLI extensions"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh extension upgrade --all 2>$null
} else {
    Warn "gh not found, skipping"
}

Section "Chezmoi"
if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    chezmoi update --apply=false 2>$null
} else {
    Warn "chezmoi not found, skipping"
}

Write-Host "`nAll done!" -ForegroundColor Green
