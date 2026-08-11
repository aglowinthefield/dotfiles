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
