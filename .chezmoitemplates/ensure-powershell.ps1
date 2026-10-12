# Bootstrap with built-in Windows PowerShell, before any pwsh setup scripts.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required. Install/update Microsoft App Installer before applying dotfiles.'
}

# Without --no-upgrade, install upgrades an existing installation as needed.
# Explicit MSI selection keeps the stable path used by Terminal and chezmoi.
winget install --exact --id Microsoft.PowerShell --source winget --installer-type wix --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
if ($LASTEXITCODE -notin @(0, -1978335189, -1978335135, 3010)) {
    throw "PowerShell installation/upgrade failed (exit code $LASTEXITCODE)."
}
$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-Path -LiteralPath $pwshPath)) {
    throw "PowerShell 7 was not found at $pwshPath after installation."
}
$version = & $pwshPath -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
if ($LASTEXITCODE -ne 0 -or [version]$version -lt [version]'7.2') {
    throw "PowerShell 7 verification failed: $version"
}
Write-Host "PowerShell $version ready at $pwshPath"
