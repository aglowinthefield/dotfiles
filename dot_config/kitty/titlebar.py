# Keeps the macOS titlebar the colour of the terminal background whatever theme
# is active. Loaded from kitty.conf as a global watcher.
#
# The titlebar colour can't simply live in kitty.conf: when kitty applies a
# dark/light/no-preference *.auto.conf it first resets every colour to kitty's
# built-in defaults (macos_titlebar_color system), not to kitty.conf's values,
# and `kitten themes` rewrites those files whole. So re-assert it after every
# theme application instead.
from typing import Any

from kitty.colors import patch_colors
from kitty.constants import is_macos
from kitty.fast_data_types import add_timer, get_options

BACKGROUND = 1  # macos_titlebar_color's value for "background"
_pending = False


def _schedule() -> None:
    # Kitty marks the tab bar dirty part-way through patch_colors and sets the
    # titlebar after that, so run on the next loop tick, once it's done.
    global _pending
    if is_macos and not _pending and get_options().macos_titlebar_color != BACKGROUND:
        _pending = True
        add_timer(_restore, 0, False)


def _restore(timer_id: int | None = None) -> None:
    global _pending
    try:
        patch_colors({'macos_titlebar_color': BACKGROUND}, configured=True)
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
