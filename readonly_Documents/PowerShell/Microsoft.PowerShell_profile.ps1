oh-my-posh --config "$HOME/Documents/OMP/uew.omp.json" init pwsh | Invoke-Expression

$env:XDG_CONFIG_HOME = "$HOME/.config"
$env:EDITOR = "nvim"

Set-Alias vim nvim
Set-Alias ls eza
Set-Alias c clear

function x { exit }
function gs { git status }
function gd { git diff }
function gdc { git diff --cached }
