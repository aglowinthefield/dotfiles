# Global Pi instructions

## Worktrees
- Work that edits tracked files gets its own worktree and branch, never the main checkout. Before the first edit, run `git worktree add .worktrees/<branch> -b <branch> <base>` from the repo root (base is `main`/`origin/main` unless the work stacks on another branch), then use absolute paths into that worktree for every read, edit and command. This matches worktrunk's layout (`~/.config/worktrunk/config.toml`), so `wt` can manage the worktree afterwards. If `.worktrees/` isn't in the repo's `.gitignore`, add it in the worktree's first commit.
- Already in a linked worktree (`git rev-parse --git-dir` contains `/worktrees/`, as in Bakery card runs)? Stay there.
- Investigation and review that edit no files can stay in the root.
- Why: the root is shared by other sessions, Bakery approvals (which merge into local `main` and refuse when main is dirty) and the operator's own editing. Uncommitted edits left there block merges and get mixed up with unrelated work.
- In the root, don't stash, reset, checkout, clean or reformat files you didn't create, even briefly to compare test results. Commit your worktree's work before you report done.

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

## Vault location
- Use `$DEV_VAULT` for the dev vault; when unset, use `~/Documents/Dev`. Resolve it before accessing notes. Keep agent reports and annotations in this vault.

## Written reports
- Vault notes take their title from the filename. Never start a note with an H1; begin with frontmatter, then the first paragraph or an H2. Frontmatter values must be valid YAML: lists as `- item` lines, and a wikilink as the whole value of its own property (`superseded-by: "[[Note]]"`), never mixed into prose.
- Reports, audits, investigations and plans that run past a short reply go in the Obsidian vault as Markdown, never `/tmp`. Each project has a top-level folder: Silk work goes under `$DEV_VAULT/Silk/<topic>/`, other projects under `$DEV_VAULT/<project>/`. Name the file for its content (`CI scripts audit.md`), tell the user the path, and wait for their review before acting on it. Scratch data (query output, logs) may stay in `/tmp`.
- Delegates writing a report get the vault path in their task, not `/tmp`.

## Systems
- Tom seeks new systems when the current one gets uncomfortable. Default to tweaking the current system (Bakery cards, skills, charters, vault `🌀 Now/` pages). When he proposes a new tool, workflow or framework for the same job, say so, ask what the current system failed at, and offer the smallest tweak first. Switch only when he names a concrete failure the tweak cannot fix.
- Annotation loop: he annotates files with `<leader>ya` in nvim, which appends to `$DEV_VAULT/Annotations/<repo or file>.md`. "Read my annotations" means the `annotations` skill.
