# General aliases that are used regardless of platform
alias x exit
alias c clear
alias vim nvim
alias cc "claude --dangerously-skip-permissions"

# Alacritty appearance. Bare `theme`/`font` report what is set; `theme pick` and
# `font pick` browse every installed palette or family with the terminal
# repainting live as you move.
alias theme alacritty-theme
alias font alacritty-font

# Fish
alias sf "source ~/.config/fish/config.fish"
alias conf "vim ~/.config"

# Git
alias gs "git status"
alias gd "git diff"
alias gdc "git diff --cached"
alias gco "git checkout"

# Markdown. `md` is mdcat: no pager, so it composes in a pipeline and is fast
# enough to not think about. `mdp` pages the same doc through glow, which has
# richer colour and emits OSC-8 links that alacritty makes clickable;
# `glow -t <dir>` browses a whole tree of docs.
alias md mdcat
alias mdp "glow -p"
