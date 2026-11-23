# Repository guidance

This repository is the chezmoi source state for cross-platform dotfiles.

- Edit managed files in this source tree, not only their rendered files in `$HOME`.
- Preserve chezmoi naming conventions and Go template directives.
- Keep platform-specific behavior inside the appropriate `.chezmoi.os` template guard.
- Before committing, run `chezmoi diff` and validate the syntax of any rendered configuration that changed.
- Do not commit secrets or rendered contents from private source templates.

## worktree-sweep

`dot_local/bin/executable_worktree-sweep` removes finished worktrees under `<repo>/.worktrees/` for every repo in `$WORKTREE_SWEEP_ROOTS` (default `~/code:~/silk`). The script header lists its removal rules. chezmoi deploys the script to every Unix machine, but each OS schedules it differently. When you set up a machine or are asked whether the sweep runs, check its OS:

- Linux: chezmoi installs `worktree-sweep.timer` (every 2 hours) and enables it through `.chezmoiscripts/run_onchange_after_58_worktree-sweep.sh.tmpl`. Check it with `systemctl --user list-timers worktree-sweep.timer` and read results with `journalctl --user -u worktree-sweep`.
- macOS: chezmoi does not schedule it. Run `worktree-sweep --install-agent` once, which writes the `cx.worktree-sweep` launchd agent (every 2 hours). Check it with `launchctl print gui/$(id -u)/cx.worktree-sweep` and read `~/Library/Logs/worktree-sweep.log`.
- Windows: not scheduled. The script needs bash, and `wt` there is Windows Terminal.

`worktree-sweep` with no flags is a dry run. Run it before `--apply` after changing the rules.

## Agent performance jobs (Linux)

chezmoi installs and enables these timers on Linux through `.chezmoiscripts/run_onchange_after_59_agent-perf-timers.sh.tmpl`. macOS does not schedule them.

- `silk-deps-seed.timer` runs `~/.local/bin/silk-deps-seed` hourly. It keeps a locked worktree at `~/code/silk-remix/.worktrees/_deps-seed` on `origin/main` with a fresh `npm ci`, so silk-remix's `scripts/worktree-deps.sh` hardlinks new worktrees' `node_modules` from it instead of installing. It exits quietly where silk-remix is not cloned. Check it with `journalctl --user -u silk-deps-seed`.
- `git-maintenance@{hourly,daily,weekly}.timer` run `git maintenance` for the repos listed in `~/.config/git/maintenance.gitconfig`. That file is per machine and unmanaged. `.gitconfig` includes it. Add a repo with `git -C <repo> maintenance register --config-file ~/.config/git/maintenance.gitconfig`, never plain `git maintenance start`, which writes into the managed `.gitconfig`.
