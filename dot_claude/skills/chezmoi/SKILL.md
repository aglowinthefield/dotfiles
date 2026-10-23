---
name: chezmoi
description: How to work on this user's chezmoi-managed dotfiles — the source repo, template and hostname conventions, secret handling, and the failure modes that have bitten before. Use whenever the task touches dotfiles, ~/.local/share/chezmoi, a chezmoi command (status/diff/apply/re-add/add), or a config file that turns out to be chezmoi-managed.
---

# Working on the chezmoi dotfiles

Source: `~/.local/share/chezmoi`. Remote `aglowinthefield/dotfiles`, branch `main`.
**The repo is public.** Everything below about secrets follows from that.

Machines, by `.chezmoi.hostname`: `mochi` (Arch home server), `tomauty` (server, no
signing agent), plus macOS laptops. `.chezmoi.os` is `darwin` / `linux` / `windows`.

## The loop

1. **Pull first**, always: `chezmoi git pull -- --rebase`. Expect uncommitted source
   edits or unpushed commits on any given machine — rebase onto `origin/main` rather
   than merging, and surface conflicts rather than resolving them silently.
2. **Show `chezmoi status` and `chezmoi diff` and walk the user through it before
   applying anything.** `chezmoi apply` needs `--force` where the target changed since
   chezmoi last wrote it — that friction is deliberate. Treat every removal in the diff
   as possible data loss and ask.
3. **When the live file is better than the source, fix the source template** — add an
   OS or hostname conditional — then apply. Never apply over a good live config, and
   never resolve the difference by deleting the machine-specific behaviour. If a
   setting only makes sense on one machine, make it conditional.
4. **Commit and push only once it validates.** Commits are SSH-signed via 1Password;
   `git log --format='%G?'` should print `G`.

## Templates

Conditionals are the whole design; look at `empty_dot_gitconfig.tmpl` and
`dot_config/starship.toml.tmpl` for the house style — `{{- if eq .chezmoi.os "darwin" }}`
/ `{{- if eq .chezmoi.hostname "mochi" }}`, with a comment saying *why* the branch
exists, not what it does.

**Do not use `chezmoi re-add` on a `.tmpl` file.** It flattens the conditionals and
drops every comment. Merge changes into templates by hand and show the user the result.

## Secrets

- Central store is `~/.config/secrets.env` (mode 600), loaded by `config.fish` on every
  OS — not inside the linux block. Ignored on Windows.
- It is provisioned from the 1Password item **`dotfiles-secrets`** by
  `dot_config/create_private_secrets.env.tmpl`. The `create_` prefix means chezmoi
  writes it only when absent, so local edits survive; to pull a rotated key, delete the
  file and apply again.
- **That cuts both ways: a value added to the live file by hand and not to the
  1Password item is lost on the next fresh machine or delete-to-rotate.** If you add a
  key to `secrets.env`, add it to the 1Password item too (`op item edit`).
- Never commit a secret. Some keys in that template are inventory only — tools with
  their own YAML (beets, caesura) don't read env vars, and the real value still lives
  in the tool's config.

## Claude Code config

`~/.claude/settings.json` is written by tooling at runtime — herdr installs its own
session hook — so it is managed as `create_private_settings.json`: chezmoi seeds a new
machine and then never touches it again, the same bargain as `secrets.env`. To change
the baseline, edit the source; the live file on an existing machine stays under the
tools' ownership.

The source deliberately omits two things. The `hooks` block hardcodes absolute fnm node
paths (one of them PID-scoped) that are valid on exactly one machine.
`autoMode.environment` names the Tailscale IP, mochi's login user and a list of
credential file paths — **the repo is public**. Let the tools regenerate both locally.

`~/.claude/settings.local.json` is machine-local by design and stays unmanaged.

## Hermes home

`~/.hermes` is a checkout of the private `aglowinthefield/hermes-home`, set up by
`57_hermes-home` and fast-forwarded on every apply by `58_hermes-home-pull`. A dirty or
diverged checkout makes 58 skip the pull without failing, so look there when a host
falls behind. On Windows both are skipped (they're `#!/bin/sh`) and
`56_hermes-home.ps1` does the same job behind a `~/.hermes` → `%LOCALAPPDATA%\hermes`
junction, without the `hermes-local-keys` filter. It also sets User-scope
`GIT_SSH_COMMAND`, since Hermes' injected `core.sshCommand` otherwise sends its
git children to Git for Windows' bundled ssh, which can't reach the 1Password agent.
56 and 58 also run `hermes plugins update charm`, since Charm tracks `main` rather
than a pack pin; a host still on a pinned install warns until Charm is removed and reinstalled (`--force` keeps the pin). Per-host state stays out of that repo: `cron/jobs.json` is untracked, and
each host's UI picks for `display.pet`, `dashboard.theme`, `terminal.font_family` and
`desktop.font_family` in the root and profile
`config.yaml` files go through the `hermes-local-keys` git filter
(`dot_local/bin/executable_hermes-local-keys`). The filter strips them on commit and
restores the host's values on checkout. 58 registers it and stashes the values before
each pull. To make another key per-host, add it to `LOCAL` in that script, not to
`.gitignore`.

## `.chezmoiignore`

Patterns match the **target path relative to `$HOME`**, not the source name and not a
basename. A bare `komorebi.json` only ever matched `~/komorebi.json` — which is why the
real `.config/komorebi/komorebi.json` kept applying to macOS for months. Always write
the full target path. Also: the file is itself a template, so scope Windows-only and
mochi-only entries inside `{{- if ... }}` blocks rather than ignoring globally.

## Failure modes seen before

- An **alacritty `import` path that doesn't exist fails silently** — you get alacritty's
  default `#1a1a1a` and no error. Verify the theme file actually exists at the
  templated path after any change to the checkout prefix.
- **A setting parked in the wrong OS block never applies and never complains.** Both
  `secrets.env` loading and `ENABLE_LSP_TOOL` sat inside `linux` for a long time and so
  were dead on macOS. When something "should already work" but doesn't, check which
  conditional it's nested in before debugging the tool.
- `run_once_*` scripts only run once per machine, keyed on content — renaming or
  editing one re-runs it. `run_onchange_*` re-runs on content change. Check
  `.chezmoiscripts/` before adding provisioning logic elsewhere.
