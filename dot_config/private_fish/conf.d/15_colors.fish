# Syntax highlighting and fzf colours, from the token colorscheme.
#
# ANSI palette *names* and numbers, not the hex in token's own
# contrib/fish/token.theme — the same reasoning as starship.toml. The terminal
# redefines those sixteen slots per variant, so `alacritty-theme light` repaints
# the prompt and the picker along with everything else. Hex would freeze this at
# one variant, and token's dark hues sit at 2–3:1 on its #faf9f5 light
# background.
#
# Set here rather than through `fish_config theme choose token`, which writes
# *universal* variables into fish_variables — machine-local state chezmoi does
# not manage, and one more thing to redo per machine.
#
# The mapping follows token's fish extra role for role; only the four values it
# picks off-palette (end, comment, autosuggestion, search_match) round to the
# nearest ANSI slot, since there is no slot for a mid grey.

if status is-interactive
    # --- fish syntax highlighting -------------------------------------------
    set -g fish_color_normal normal
    set -g fish_color_command blue
    set -g fish_color_keyword bryellow
    set -g fish_color_quote green
    set -g fish_color_redirection magenta
    set -g fish_color_end white
    set -g fish_color_error red
    set -g fish_color_param white
    set -g fish_color_comment brblack
    set -g fish_color_selection --reverse
    set -g fish_color_operator brred
    set -g fish_color_escape magenta
    set -g fish_color_autosuggestion brblack
    set -g fish_color_cwd blue
    set -g fish_color_cwd_root red
    set -g fish_color_user green
    set -g fish_color_host blue
    set -g fish_color_host_remote bryellow
    set -g fish_color_status red
    set -g fish_color_cancel red
    set -g fish_color_search_match --background=brblack
    set -g fish_color_history_current brred
    set -g fish_color_valid_path --underline

    # --- fish pager ---------------------------------------------------------
    set -g fish_pager_color_progress brred
    set -g fish_pager_color_prefix brred --bold
    set -g fish_pager_color_completion normal
    set -g fish_pager_color_description brblack
    set -g fish_pager_color_selected_background --reverse
    set -g fish_pager_color_selected_prefix brred --bold
    set -g fish_pager_color_selected_completion normal
    set -g fish_pager_color_selected_description brblack

    # --- fzf ----------------------------------------------------------------
    # Numbers are the same sixteen slots; -1 means "whatever the terminal is
    # using", which keeps the picker's background continuous with the pane
    # instead of painting a block over it.
    if command -q fzf
        set -gx FZF_DEFAULT_OPTS (string join " " -- \
            $FZF_DEFAULT_OPTS \
            --border \
            '--color=fg:-1,bg:-1,hl:9' \
            '--color=fg+:-1,bg+:8,hl+:9' \
            '--color=border:8,header:4,gutter:-1' \
            '--color=spinner:11,info:8' \
            '--color=pointer:9,marker:2,prompt:9')
    end
end
