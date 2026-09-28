# ---------------------------------------------------------------------------
# Interactive-only setup
# ---------------------------------------------------------------------------
# Everything in this block needs a real console. In a redirected session these
# do not fail, they BLOCK: `Import-Module CompletionPredictor` registers an
# ICommandPredictor subsystem and never returns, and PSReadLine and starship's
# Enable-TransientPrompt both drive the line editor. -ErrorAction
# SilentlyContinue is no help against a hang.
#
# That cost an afternoon once: `chezmoi apply` runs .ps1 scripts as
# `pwsh -NoLogo -File` with the streams redirected, which loads this profile —
# so every apply hung on its first script with no output, no error and no
# timeout. chezmoi now passes -NoProfile (see .chezmoi.toml.tmpl), but any other
# non-interactive `pwsh -File` — a scheduled task, CI, a git hook — would hit
# the same wall, so the guard belongs here too.
#
# Testing the host does not work: $Host.Name is 'ConsoleHost' and
# [Environment]::UserInteractive is $true under `pwsh -File` exactly as they are
# in a terminal. The redirection flags are what actually differ — all false in a
# terminal, all true when something is capturing the output.
if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {

    # Modules
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue
    Import-Module PSFzf -ErrorAction SilentlyContinue

    # PSReadLine — fish-like experience
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

    # Prompt. Cache generated with:
    #   starship init powershell --print-full-init > ~/.config/starship/init.ps1
    # Regenerate after updating starship.
    . "$HOME/.config/starship/init.ps1"

    function Invoke-Starship-TransientFunction {
        "~ "
    }
    Enable-TransientPrompt
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# Outside the guard on purpose: setting a variable costs nothing and a script
# that inherits EDITOR or XDG_CONFIG_HOME is better off for it.
$env:XDG_CONFIG_HOME = "$HOME/.config"
$env:EDITOR = "nvim"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
Set-Alias vim nvim
Set-Alias ls lsd
Set-Alias c clear

function x { exit }
# Mirrors the fish `cc` alias in .config/fish/conf.d/10_general_alias.fish.
# A function rather than Set-Alias because Set-Alias cannot carry arguments;
# @args forwards anything extra, so `cc -p "..."` still works.
function cc { claude --dangerously-skip-permissions @args }
function gs { git status }
function gd { git diff }
function gdc { git diff --cached }
if (-not (Get-Command poetry -ErrorAction Ignore)) { $env:Path += ";C:\Users\clearing\AppData\Roaming\Python\Scripts" }
