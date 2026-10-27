# User Preferences

## Less code

- Prefer the change that leaves less code to maintain: reuse an existing seam, delete dead or
  superseded paths, and justify every new file, abstraction, option, or dependency. A diff that
  removes more than it adds is a good sign. "Less" means fewer concepts to maintain, not line-count
  golf or cramming logic into one place.
- Do not add speculative generality: no config knobs, extension points, or modes the task doesn't
  need.

## ClearStack
- Apply the `clear-mode` skill to every non-trivial engineering task. Repo instructions still win where they are stricter.

## Voice
- Before writing any final report, summary, commit message, PR body, handoff note or other write-up, read `~/.agents/skills/clear-voice/SKILL.md` and follow it. Keep write-ups short: no bold-label sections, no restating internals the reader didn't ask about.

## Pull requests
- Stacked PRs are allowed across projects. A dependent PR may branch from and target its parent PR branch; do not wait for the parent to merge solely to avoid stacking.
- Kanban implementers and AI reviewers hand off after local verification and review without waiting for CI. Report the pushed head and observed CI state; required checks still gate merging.
