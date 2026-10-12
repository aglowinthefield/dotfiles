# Windows setup

Machine choices live in `~/.config/chezmoi/chezmoi.toml`, under `[data]`:

```toml
[data]
vfox = false
windowsDesktop = false
windowsExtraApps = false
windowsExtraFonts = false
```

Keep the generated interpreter sections: the first bootstrap runs with built-in
Windows PowerShell through cmd, then setup scripts run with PowerShell 7's
absolute install path and `-NoLogo -NoProfile -File`.

The default includes the existing Windows-compatible configs for PowerShell,
Windows Terminal, Git, SSH, Neovim, herdr configs, and agent tools. Package
installation includes terminal/editor development dependencies, 1Password for
Git signing and SSH, and JetBrains Mono and Recursive fonts used by the terminal
configs. Starship and fzf are included for the PowerShell profile.
Windows does not install psmux/tmuxpanel or manage tmux configs. After package
installation, setup installs missing PSFzf, CompletionPredictor, and PSReadLine
modules for the current user, then installs herdr using its official stable
installer if it is absent. Existing herdr installations are preserved.
The existing macOS/Linux tmux configuration is preserved.
Alacritty is no longer installed or configured on any platform. Shared palette
assets live under `~/.local/share/terminal-palettes`; Ghostty tooling remains.

Optional bundles:

- `windowsDesktop`: komorebi, whkd, and yasb packages and configs, komorebi
  long-path setup and autostart, and the WHKD_CONFIG_HOME environment variable.
- `windowsExtraApps`: the remaining Scoop and winget apps, including Blender,
  Adobe Creative Cloud, Docker, Steam, VirtualBox, and Visual Studio.
- `windowsExtraFonts`: the existing full Nerd Font collection.

Disabling a bundle stops managing/installing it; it does not uninstall apps,
delete previously applied configs, or undo previously enabled autostart.
Other existing setup scripts, including registry tweaks and the sysupdate
scheduled task, remain enabled. Review the dry run before the first application.
Each full apply first uses WinGet to install or upgrade the latest stable
PowerShell 7 using its MSI installer. WinGet/App Installer must be available;
installation can require Windows elevation. Failed installation stops the apply.
PowerShell does not need to be installed or on PATH beforehand. Windows Terminal's
default profile launches `%ProgramFiles%\PowerShell\7\pwsh.exe` explicitly, so it
uses the upgraded stable version rather than Windows PowerShell 5.1 or a preview.
Updates occur when applying, not each time a terminal tab opens. Open a new tab
after updating; an already-running shell keeps its existing version.

Windows excludes Fish, Unix Node shims, Hermes helpers, shell hook wrappers,
and the currently Unix-only reviewr plugin configuration/keybinding. Agent
hooks invoke Python directly with a machine-specific absolute script path.
Claude and Codex hook settings are seeded only when absent (`create_` files),
so existing local hook settings are preserved and need updating separately.

## Review and apply

Clone/init without applying, edit the local choices, and preview:

```powershell
chezmoi init aglowinthefield/dotfiles
chezmoi diff
chezmoi apply --dry-run --verbose
# When the config and preview are ready:
chezmoi apply
```

Git config enables 1Password SSH signing and rewrites GitHub HTTPS URLs to SSH.
Set up the 1Password SSH agent, the matching GitHub key, and op-ssh-sign before
using that config to commit or push. Confirm with `ssh -T git@github.com`.

## Pull and push

Pull separately from application so there is time to inspect updates:

```powershell
chezmoi git -- pull --rebase --autostash
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

Edit managed source files with `chezmoi edit <target-path>`. If you edited a live
config, transfer the intended edits into its source file while preserving any
template conditionals. Do not re-add managed files or add secrets.

```powershell
chezmoi git -- diff
chezmoi diff
chezmoi git -- add <source-paths>
chezmoi git -- commit -m "Update Windows config"
chezmoi git -- push
```

The local `[data]` choices are machine-specific and are not pushed. The config
template preserves them when running `chezmoi init` again.
