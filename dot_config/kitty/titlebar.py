# Keeps window chrome in step with the active theme, whatever theme is picked.
# Loaded from kitty.conf as a global watcher.
#
# - The macOS titlebar takes the terminal background.
# - Tab colours a theme leaves unset are derived from its background and
#   foreground instead of kitty's fixed light-grey pills.
#
# Neither can simply live in kitty.conf: when kitty applies a dark/light/
# no-preference *.auto.conf it first resets every colour to kitty's built-in
# defaults, not to kitty.conf's values, and `kitten themes` rewrites those
# files whole. So re-assert them after every theme application instead.
from typing import Any

from kitty.colors import patch_colors
from kitty.constants import is_macos
from kitty.fast_data_types import Color, add_timer, get_options
from kitty.options.types import defaults

TITLEBAR_BACKGROUND = 1  # macos_titlebar_color's value for "background"

# Tab colour -> how far to move from the background toward the foreground.
# Only applied while the option still holds kitty's default, i.e. the theme
# didn't set it.
TAB_MIX = {
    'active_tab_background': 0.16,
    'active_tab_foreground': 1.0,
    'inactive_tab_background': 0.07,
    'inactive_tab_foreground': 0.55,
}

_pending = False


def _mix(bg: Color, fg: Color, t: float) -> int:
    r, g, b = (round(a + (c - a) * t) for a, c in ((bg.red, fg.red), (bg.green, fg.green), (bg.blue, fg.blue)))
    return (r << 16) | (g << 8) | b


def _wanted() -> dict[str, int]:
    opts = get_options()
    spec: dict[str, int] = {}
    if is_macos and opts.macos_titlebar_color != TITLEBAR_BACKGROUND:
        spec['macos_titlebar_color'] = TITLEBAR_BACKGROUND
    for key, t in TAB_MIX.items():
        current = getattr(opts, key)
        if current == getattr(defaults, key):
            value = _mix(opts.background, opts.foreground, t)
            # Skip when the derived colour *is* the default (say, black text),
            # or patching would re-trigger this forever.
            if value != int(current):
                spec[key] = value
    return spec


def _schedule() -> None:
    # Kitty marks the tab bar dirty part-way through patch_colors and sets the
    # titlebar after that, so run on the next loop tick, once it's done.
    global _pending
    if not _pending and _wanted():
        _pending = True
        add_timer(_restore, 0, False)


def _restore(timer_id: int | None = None) -> None:
    global _pending
    try:
        if spec := _wanted():
            patch_colors(spec, configured=True)
    finally:
        _pending = False


def on_load(boss: Any, data: dict[str, Any]) -> None:
    # Startup applies the auto theme before any watcher event fires.
    _schedule()


def on_tab_bar_dirty(boss: Any, window: Any, data: dict[str, Any]) -> None:
    # Fires on theme switches and config reloads, even with the tab bar hidden.
    _schedule()


def on_color_scheme_preference_change(boss: Any, window: Any, data: dict[str, Any]) -> None:
    _schedule()
