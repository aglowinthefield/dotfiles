# Repository guidance

This repository is the chezmoi source state for cross-platform dotfiles.

- Edit managed files in this source tree, not only their rendered files in `$HOME`.
- Preserve chezmoi naming conventions and Go template directives.
- Keep platform-specific behavior inside the appropriate `.chezmoi.os` template guard.
- Before committing, run `chezmoi diff` and validate the syntax of any rendered configuration that changed.
- Do not commit secrets or rendered contents from private source templates.

## worktree-sweep

worktree-sweep lives in its own repo, [aglowinthefield/worktree-sweep](https://github.com/aglowinthefield/worktree-sweep), cloned at `~/code/worktree-sweep`. Every 2 hours it fast-forwards each repo's main checkout and removes finished worktrees, for repos under `~/code:~/silk`. Change it there, not here. `.chezmoiscripts/run_onchange_after_58_worktree-sweep.sh.tmpl` clones it, links `~/.local/bin/worktree-sweep`, and schedules it on macOS and Linux. Its own refresh keeps the clone current. Windows doesn't run it.

- Linux: check with `systemctl --user list-timers worktree-sweep.timer` and `journalctl --user -u worktree-sweep`.
- macOS: check with `launchctl print gui/$(id -u)/worktree-sweep` and `~/Library/Logs/worktree-sweep.log`.

## Agent performance jobs (Linux)

chezmoi installs and enables these timers on Linux through `.chezmoiscripts/run_onchange_after_59_agent-perf-timers.sh.tmpl`. macOS does not schedule them.

- `git-maintenance@{hourly,daily,weekly}.timer` run `git maintenance` for the repos listed in `~/.config/git/maintenance.gitconfig`. That file is per machine and unmanaged. `.gitconfig` includes it. Add a repo with `git -C <repo> maintenance register --config-file ~/.config/git/maintenance.gitconfig`, never plain `git maintenance start`, which writes into the managed `.gitconfig`.
