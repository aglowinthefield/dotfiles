# macOS specific aliases. Ignored on every other OS via .chezmoiignore,
# since Homebrew is only installed on the laptops.
alias bup "brew update; brew upgrade"

# Feishin keeps its settings in one JSON file that it also writes itself, so
# chezmoi can't just re-add it -- that would publish the Navidrome token and
# commit this display's window bounds. This copies out only the shareable
# settings; commit and push, then `chezmoi update` on the other Mac.
function feishin-settings-save
    jq 'del(.server, .bounds, .maximized, .fullscreen, .__internal__,
            .should_prompt_accessibility, .shown_accessibility_warning)' \
        "$HOME/Library/Application Support/feishin/config.json" \
        >(chezmoi source-path)/.chezmoidata/feishin.json
    and echo "saved -> "(chezmoi source-path)"/.chezmoidata/feishin.json"
end
