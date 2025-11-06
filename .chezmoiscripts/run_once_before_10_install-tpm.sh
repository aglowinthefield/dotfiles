#!/bin/sh
set -eu

TPM_DIR="${HOME}/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

mkdir -p "$(dirname "${TPM_DIR}")"

if [ ! -d "${TPM_DIR}/.git" ]; then
    if [ -e "${TPM_DIR}" ] && [ ! -d "${TPM_DIR}/.git" ]; then
        printf 'TPM directory exists but is not a git repo; leaving it untouched.\n' >&2
        exit 0
    fi
    git clone --depth 1 "${TPM_REPO}" "${TPM_DIR}"
else
    git -C "${TPM_DIR}" pull --ff-only
fi
