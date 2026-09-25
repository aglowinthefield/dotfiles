# General aliases that are used regardless of platform
alias x exit
alias c clear
alias vim nvim

# AI Agents
alias cc "claude --dangerously-skip-permissions"
alias co "codex"
alias cl "claude --dangerously-skip-permissions"

# Silk work. Same as `cc`, but under Doppler so the session inherits
# silk-ops/dev_personal — the Neon MCP server reads NEON_API_KEY from the
# environment via ${NEON_API_KEY} in its Authorization header, so it only
# authenticates when launched this way. Kept as its own alias rather than
# shadowing `claude`: this environment also carries PGPASSWORD,
# STRIPE_SECRET_KEY and the R2 keys, which have no business in unrelated
# sessions.
alias cs "doppler run --no-fallback --project silk-ops --config dev_personal -- claude --dangerously-skip-permissions"

# Alacritty appearance. Bare `theme`/`font` report what is set; `theme pick` and
# `font pick` browse every installed palette or family with the terminal
# repainting live as you move.
alias theme alacritty-theme
alias font alacritty-font

# Fish
alias sf "source ~/.config/fish/config.fish"
alias conf "vim ~/.config"

# Git. Deliberately no alias for `add`, `commit` or `push`: staging wants
# explicit pathspecs rather than a two-letter habit that ends in `git add -A`,
# and push is one keystroke from a gated action, so it stays spelled out.
alias gs "git status"
alias gsb "git status --short --branch"
alias gd "git diff"
alias gdc "git diff --cached"
alias gdn "git diff --name-only"
alias gds "git diff --stat"
alias gco "git checkout"
alias gsw "git switch"
alias gswc "git switch -c"
alias gl "git log --oneline -15"
# What is on this branch and not yet on the remote — the question asked before
# every push, and the one `git log` alone answers badly.
alias glo "git log --oneline origin/main..HEAD"
alias gf "git fetch --prune"
# --ff-only rather than a plain pull: a surprise merge commit on a branch is
# harder to notice than a refused fast-forward.
alias gup "git pull --ff-only"

# GitHub
alias ghs "gh auth status"
alias ghpr "gh pr view --web"
alias ghrun "gh run list --limit 5"

# Silk verification. Both are npm scripts in silk-remix, so they only resolve
# inside that repo; elsewhere they fail loudly rather than doing something else.
alias wt "npm run worktree:truth"
alias tc "npm run typecheck"

# Markdown. `md` is mdcat: no pager, so it composes in a pipeline and is fast
# enough to not think about. `mdp` pages the same doc through glow, which has
# richer colour and emits OSC-8 links that alacritty makes clickable;
# `glow -t <dir>` browses a whole tree of docs.
alias md mdcat
alias mdp "glow -p"
