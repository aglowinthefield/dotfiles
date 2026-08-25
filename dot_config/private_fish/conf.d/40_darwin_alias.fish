# macOS specific aliases. Ignored on every other OS via .chezmoiignore,
# since Homebrew is only installed on the laptops.
alias bup "brew update; brew upgrade"

# Feishin splits its state across three places, and only some of it travels.
#
#   config.json      main-process settings. Filtered copy in .chezmoidata,
#                    merged back by the modify_ script.
#   store_settings   list/table layout, playback, hotkeys, font, css, lyrics.
#                    Only reachable through the app's own Settings > Advanced >
#                    Export settings, which downloads feishin-settings.json.
#   store_app        sidebar widths, titlebar colour. Not exportable, and not
#                    worth chasing: it also holds a `platform` value that is
#                    already wrong on this Mac, so it is not a store you want
#                    copied between machines.
#
# Run this after changing settings; it collects whatever is available. Then
# commit and push, and on the other Mac `chezmoi update` followed by
# Settings > Advanced > Import settings (the file lands next to config.json).
function feishin-settings-save
    set -l src (chezmoi source-path)
    set -l support "$HOME/Library/Application Support/feishin"

    jq 'del(.server, .bounds, .maximized, .fullscreen, .__internal__,
            .should_prompt_accessibility, .shown_accessibility_warning)' \
        "$support/config.json" >$src/.chezmoidata/feishin.json
    and echo "config.json  -> .chezmoidata/feishin.json"

    # The app exports to ~/Downloads. Blank the three credential fields rather
    # than deleting them: the import validates against a Zod schema where all
    # three are required strings, so a missing key fails the whole import.
    set -l dl "$HOME/Downloads/feishin-settings.json"
    if test -f $dl
        jq '.remote.password = "" | .general.lastfmApiKey = ""
            | .general.translationApiKey = ""' $dl \
            >"$src/private_Library/private_Application Support/private_feishin/feishin-settings.json"
        and rm $dl
        and echo "export       -> feishin-settings.json (secrets blanked)"
    else
        echo "no export found -- for layout, use Settings > Advanced > Export"
        echo "settings in Feishin, then run this again."
    end
end
