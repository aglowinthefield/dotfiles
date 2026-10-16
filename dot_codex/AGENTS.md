# User Preferences

## Memory identity
- In every session, use mem0 user ID `clearing`. For search and list calls, explicitly set `filters` to `{"AND":[{"user_id":"clearing"}]}`; for writes and other user-scoped calls, explicitly set `user_id` to `clearing`. The connector's default scope can return an empty result even when `clearing` has memories.

## Shell compatibility
- The user uses fish. Default to fish-compatible commands, terminal examples, and interactive shell snippets across projects, even when the tool execution shell is zsh or Bash.
- Use fish syntax for variables, command substitutions, loops, conditionals, and functions in snippets intended for the user to paste; avoid POSIX/Bash-only syntax and heredocs.
- When another interpreter is required, provide a fish-compatible invocation and clearly identify that interpreter.
- Preserve existing script shebangs and repository-required languages (for example, POSIX sh); this preference does not require converting project scripts to fish.
- Match commands executed by tools to the tool's actual shell, or explicitly invoke fish when validating fish snippets.

## Dotfiles (chezmoi)
- Source is `~/.local/share/chezmoi`, a public repo. Edit the source and apply; never copy live files back into it.
- Never run `chezmoi re-add`, or `chezmoi add` on a file chezmoi already manages. A live file that differs from the source is usually stale, not newer, and `re-add` flattens `.tmpl` conditionals. "Push my chezmoi changes" means committing what is already in the source, not syncing live files into it. A blanket sync on 2026-10-11 undid two weeks of commits.
- Show `chezmoi diff` before any apply, and treat every removal as possible data loss.

## Less code
- Prefer the change that leaves less code to maintain: reuse an existing seam, delete dead or superseded paths, and justify every new file, abstraction, option, or dependency. A diff that removes more than it adds is a good sign. "Less" means fewer concepts to maintain, not line-count golf or cramming logic into one place.
- Do not add speculative generality: no config knobs, extension points, or modes the task doesn't need.

## ClearStack
- Apply the `clear-mode` skill to every non-trivial engineering task. Repo instructions still win where they are stricter.

## Pull requests
- Stacked PRs are allowed across projects. A dependent PR may branch from and target its parent PR branch; do not wait for the parent to merge solely to avoid stacking.
- Kanban implementers and AI reviewers hand off after local verification and review without waiting for CI. Report the pushed head and observed CI state; required checks still gate merging.
