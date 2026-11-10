# Global Pi instructions

## Worktrees
- Work that edits tracked files gets its own worktree and branch, never the main checkout. Before the first edit, run `git worktree add .worktrees/<branch> -b <branch> <base>` from the repo root (base is `main`/`origin/main` unless the work stacks on another branch), then use absolute paths into that worktree for every read, edit and command. This matches worktrunk's layout (`~/.config/worktrunk/config.toml`), so `wt` can manage the worktree afterwards. If `.worktrees/` isn't in the repo's `.gitignore`, add it in the worktree's first commit.
- Already in a linked worktree (`git rev-parse --git-dir` contains `/worktrees/`, as in Bakery card runs)? Stay there.
- Investigation and review that edit no files can stay in the root.
- Why: the root is shared by other sessions, Bakery approvals (which merge into local `main` and refuse when main is dirty) and the operator's own editing. Uncommitted edits left there block merges and get mixed up with unrelated work.
- In the root, don't stash, reset, checkout, clean or reformat files you didn't create, even briefly to compare test results. Commit your worktree's work before you report done.

## Taste questions
- For any recommendation or taste question (what to play, watch, read, listen to, wear, visit), first call the Silk Taste Passport MCP tool `mcp__silk__silk_get_taste_passport` (deferred: reach it through codemode as `tools.mcp__silk__silk_get_taste_passport({})`). Base the answer on it and say which passport entries drove each pick. If the call fails, say so before falling back to generic picks.

## Codemode output
- For routine Codemode calls, start scripts with `// @options: {"max_output_tokens": 1200}`. Raise the limit only when the task needs more detail.
- Emit short `text()` summaries or filtered excerpts, not raw nested tool results or large `console.log()` dumps. Preserve error messages and paths needed to act.
- For long logs, keep the full output in a file and read only the relevant lines.

## Waiting
- Never wait with a fixed `sleep N`, in bash or through codemode (which has no timers). Wait on the real condition: a blocking command (`gh run watch`, `gh pr checks --watch`, `flyctl ... --wait`, `acp_delegate_wait`) or one bounded poll loop, `timeout 300 sh -c 'until <check>; do sleep 2; done'`. The `no-sleep` extension blocks bare sleeps.

## ClearStack
- Do not invoke `clear-mode` unless I explicitly ask for it.

## Voice
- Before writing any final report, summary, commit message, PR body, handoff note or other write-up, read `~/.agents/skills/clear-voice/SKILL.md` and follow it. Keep write-ups short: no bold-label sections, no restating internals the reader didn't ask about.

## Written reports
- Reports, audits, investigations and plans that run past a short reply go in the Obsidian vault as Markdown, never `/tmp`. Silk work goes under `~/silk/notes/<topic>/` (a symlink to `~/Documents/Obsidian Vault/Work/`); other work goes under `~/Documents/Obsidian Vault/`. Name the file for its content (`CI scripts audit.md`), tell the user the path, and wait for their review before acting on it. Scratch data (query output, logs) may stay in `/tmp`.
- Delegates writing a report get the vault path in their task, not `/tmp`.

## Systems
- Tom seeks new systems when the current one gets uncomfortable. Default to tweaking the system in `~/Documents/Obsidian Vault/Agent team design.md` (specs in `docs/specs/`, charters, lead and chief roles, Bakery cards, vault `Now/` pages). When he proposes a new tool, workflow or framework for the same job, say so, ask what the current system failed at, and offer the smallest tweak first. Switch only when he names a concrete failure the tweak cannot fix.
- Annotation loop: he annotates files with `<leader>ya` in nvim, which appends to `~/Documents/Obsidian Vault/Work/Annotations/<repo or file>.md`. "Read my annotations" means the `annotations` skill.
