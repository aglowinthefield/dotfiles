# Repository guidance

This repository is the chezmoi source state for cross-platform dotfiles.

- Edit managed files in this source tree, not only their rendered files in `$HOME`.
- Preserve chezmoi naming conventions and Go template directives.
- Keep platform-specific behavior inside the appropriate `.chezmoi.os` template guard.
- Before committing, run `chezmoi diff` and validate the syntax of any rendered configuration that changed.
- Do not commit secrets or rendered contents from private source templates.
