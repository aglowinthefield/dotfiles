# Scoop may have been installed by an earlier script in this same apply.
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$env:PATH = "$(Join-Path $scoopRoot 'shims');$env:PATH"
