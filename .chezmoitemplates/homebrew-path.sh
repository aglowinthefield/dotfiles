{{ if eq .chezmoi.os "darwin" -}}
# Each chezmoi script runs in a separate process; bootstrap PATH is not inherited.
if ! command -v brew >/dev/null 2>&1; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi
{{ end -}}
