# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------
Import-Module CompletionPredictor -ErrorAction SilentlyContinue
Import-Module PSFzf -ErrorAction SilentlyContinue

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
Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine

# PSFzf — fuzzy history & file search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# ---------------------------------------------------------------------------
# Prompt & environment
# ---------------------------------------------------------------------------
# Cache generated with: starship init powershell --print-full-init > ~/.config/starship/init.ps1
# Regenerate after updating starship.
. "$HOME/.config/starship/init.ps1"

function Invoke-Starship-TransientFunction {
    "~ "
}
Enable-TransientPrompt

$env:XDG_CONFIG_HOME = "$HOME/.config"
$env:EDITOR = "nvim"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
Set-Alias vim nvim
Set-Alias ls lsd
Set-Alias c clear

function x { exit }
function gs { git status }
function gd { git diff }
function gdc { git diff --cached }
