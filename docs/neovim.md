# Neovim setup and verification

The managed configuration is `dot_config/nvim`. Edit it here, then apply it with
`chezmoi apply --include dirs,files ~/.config/nvim`. Do not copy live configuration over
the source directory: review any differences first. On Windows the PowerShell
profile exposes this configuration through the Neovim standard configuration path.
Use `:echo stdpath('config')` to check the location on any machine.

## Requirements

- Neovim 0.12 or newer. The Treesitter `main` branch and native LSP setup require a
  current Neovim; daily plugin updates do not upgrade Neovim itself.
- Git for plugins, `rg` and `fd` for Snacks search, `tree-sitter` CLI, a C compiler,
  `curl` and `tar` for parser installation. A Tree-sitter runtime library alone is
  not the CLI. Treesitter's current CLI minimum is reported by its health check.
- Node for JavaScript language tools. Use fnm and the project's `.nvmrc`.
- StyLua for Lua formatting, lazygit for the `,gg` terminal UI.

`.chezmoidata/packages.yaml` provisions StyLua and lazygit on macOS, Arch Linux,
and Windows, plus ripgrep and the Tree-sitter CLI where they were missing.
macOS needs Xcode Command Line Tools for the C compiler; Arch includes
`base-devel`; Windows provisions GCC. Package-manager installation of Neovim is
not a guarantee of the required version: check `nvim --version` after provisioning.

Swift (`sourcekit-lsp`), .NET (`dotnet`, `netcoredbg`, `dotnet-csharpier`), and
Windows PowerShell (`pwsh`) are optional language/workflow dependencies. SourceKit
is enabled only when available. Missing debugger and lazygit executables produce
an actionable notification when used. Formatters that are unavailable are skipped;
`:ConformInfo` explains what Conform can run. On Windows, absent `pwsh` leaves
Neovim's existing shell unchanged.

Run `:checkhealth dotfiles nvim-treesitter mason snacks vim.provider` to diagnose
tools and platform capabilities. Missing optional tools are not required for
ordinary editing.

## Layout

- `init.lua`: module startup order, not plugin/editor implementation.
- `lua/config/options.lua`: editor defaults.
- `lua/config/autocmds.lua`: buffer-local indentation and reload-safe autocmds.
- `lua/config/keys.lua`: non-plugin mappings.
- `lua/config/runtime.lua`: version, shell and executable checks.
- `lua/config/formatting.lua`: project formatter-config discovery.
- `lua/config/lazy.lua`: plugin manager/bootstrap.
- `lua/config/auto-update.lua`: throttled, background plugin updates.
- `lua/plugins/completion.lua`: Blink completion.
- `lua/plugins/treesitter.lua`: parsers, highlighting, textobjects.
- `lua/plugins/lsp.lua`: language servers and diagnostic behavior.
- Other `lua/plugins/*.lua`: individual plugin/workflow specifications.

Horizon Dark remains the default; both Kanagawa variants remain available. File
and project navigation stays with Snacks rather than another finder or tree.

## Formatting

JavaScript/TypeScript formatting uses the project's Prettier binary and config,
then applies ESLint fixes. Config discovery includes Prettier's TypeScript and
TOML filenames and a `prettier` field in `package.json`, searching upward from
the edited file. A package manifest without that field does not stop discovery.
Malformed manifests do not break saving. Conform prefers a project-local binary
over a global one. TypeScript Prettier configs still require a
Node version supported by the project's Prettier installation.

Lua uses StyLua. Existing Rust, C#, Swift and C/C++ formatters are retained.

## Clipboard

`unnamedplus` delegates to Neovim's normal provider detection. macOS uses
`pbcopy`/`pbpaste`; Windows uses its supported local clipboard provider. Linux
needs a clipboard provider appropriate to the actual session (Wayland or X11).
Do not force `wl-copy` merely because it is installed on a headless server.

Over SSH, OSC52 support is terminal-dependent. Inspect `:checkhealth vim.provider`
first. If detection is insufficient and the terminal supports OSC52, explicitly
configure `vim.g.clipboard = 'osc52'` for that environment; OSC52 paste may be
restricted by terminal permissions. Do not impose this globally on local sessions.

## Verification

From the source repository:

```sh
nvim --headless -u NONE -l tests/nvim/config.lua
nvim --headless -u NONE -l tests/nvim/auto-update.lua
nvim --headless -u NONE -l tests/nvim/formatting.lua
nvim --headless -u NONE -l tests/nvim/runtime.lua
nvim --headless '+luafile tests/nvim/live.lua'
chezmoi diff --recursive --include files --no-pager ~/.config/nvim
```

Isolated tests simulate platform/capability cases; they do not substitute for
running the configuration on Windows and Linux. Full startup, formatter execution
and health checks should also be run on the machine receiving the config. The
source-only tests and this document are ignored by chezmoi and are not deployed
into the home directory.
