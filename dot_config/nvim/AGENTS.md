# Neovim agent guide

## Source and workflow
- This directory is chezmoi-managed as `dot_config/nvim` in `~/.local/share/chezmoi`.
- When working in the live config, find the source with `chezmoi source-path ~/.config/nvim`; edit the source worktree, not only deployed files.
- Read `docs/neovim.md` in the source repository for setup, layout, formatting behavior, and platform requirements.
- Run source commands below from the source worktree root, not this directory.
- Review `chezmoi --source "$PWD" diff --recursive --include files --no-pager ~/.config/nvim` before applying from a worktree.
- Get approval before applying; use `chezmoi --source "$PWD" apply --include dirs,files ~/.config/nvim` to avoid unrelated dotfiles and scripts.
- Preserve live-only changes when reconciling differences; do not overwrite them with older source files.

## Where changes belong
- Keep `init.lua` limited to startup order; editor defaults, mappings, and autocmds belong in `lua/config/`.
- Add plugin specifications in `lua/plugins/`; `lua/config/lazy.lua` imports that directory.
- Put non-plugin mappings in `lua/config/keys.lua`; leaders are `,` and `\`.
- Keep runtime capability checks in `lua/config/runtime.lua` and health reporting in `lua/dotfiles/health.lua`.
- Update source-repo `docs/neovim.md` when requirements or user-visible workflows change.

## Constraints
- Require Neovim 0.12+; preserve native LSP and the Treesitter `main` API.
- Keep Blink completion and Snacks navigation unless the user requests a replacement.
- Preserve project-local Prettier/config resolution and ESLint fix ordering; see `lua/config/formatting.lua` and `lua/plugins/conform.lua`.
- Keep autocmd groups reload-safe and optional tools capability-gated across macOS, Linux, and Windows.
- Keep daily plugin updates backgrounded and disabled in headless, piped-input, and Git commit/rebase sessions.
- `lazy-lock.json` is deliberately unmanaged; do not add it to chezmoi source state.

## Checks
| Scope | Command from source worktree root |
| --- | --- |
| Editor defaults and autocmds | `nvim --headless -u NONE -l tests/nvim/config.lua` |
| Key mappings | `nvim --headless -u NONE -i NONE -l tests/nvim/keys.lua` |
| Update scheduling | `nvim --headless -u NONE -l tests/nvim/auto-update.lua` |
| Formatter selection | `nvim --headless -u NONE -l tests/nvim/formatting.lua` |
| Platform and tool checks | `nvim --headless -u NONE -l tests/nvim/runtime.lua` |
| Deployed config integration | `nvim --headless '+luafile tests/nvim/live.lua'` |

- Run the matching isolated tests before applying; the integration test loads the live config, not un-applied source edits.
- After approved deployment, check `:checkhealth dotfiles nvim-treesitter mason snacks vim.provider` and `:ConformInfo` for affected tools.
- Report checks actually run and distinguish source validation from live verification.
