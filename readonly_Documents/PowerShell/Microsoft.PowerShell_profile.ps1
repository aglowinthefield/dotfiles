# ---------------------------------------------------------------------------
# PSReadLine — fish-like experience
# ---------------------------------------------------------------------------
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -BellStyle None

# Fish-style keybindings
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardChar
Set-PSReadLineKeyHandler -Key End -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Key Ctrl+f -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine

# ---------------------------------------------------------------------------
# Prompt & environment
# ---------------------------------------------------------------------------
oh-my-posh --config "$HOME/Documents/OMP/uew.omp.json" init pwsh | Invoke-Expression

$env:XDG_CONFIG_HOME = "$HOME/.config"
$env:EDITOR = "nvim"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
Set-Alias vim nvim
Set-Alias ls eza
Set-Alias c clear

function x { exit }
function gs { git status }
function gd { git diff }
function gdc { git diff --cached }
