# Global kitty watcher (loaded by `watcher ssh_tint.py` in kitty.conf).
#
# Tints a window's background faintly blue while ssh (or mosh) is its foreground
# program, so a remote shell is obvious at a glance, and drops the tint when
# the session ends. The blue comes from the Compline palette.
#
# Shell integration reports each command start/stop (OSC 133). A start whose
# command line is ssh tints at once; a recheck shortly after catches wrappers
# (fish functions, aliases) by looking at the real foreground process. Remote
# shells emit the same marks through the ssh session, so every decision checks
# what is actually running in the local pty instead of trusting the last mark.
#
# The tint is a blend of the window's configured background toward Compline blue, so
# it follows the dark/light auto themes; a macOS appearance switch re-derives
# it from the new theme.

from __future__ import annotations

import os
import shlex
from typing import Any

from kitty.colors import patch_colors
from kitty.constants import is_macos
from kitty.fast_data_types import add_timer, get_options

# Fraction of the way from the theme background toward TINT_TARGET.
TINT_STRENGTH = 0.06
TINT_TARGET = (0xB4, 0xBC, 0xC4)  # Compline blue: #b4bcc4
REMOTE_PROGRAMS = {'ssh', 'mosh', 'mosh-client', 'autossh', 'et'}
WRAPPER_WORDS = {'env', 'command', 'exec', 'builtin', 'nice', 'caffeinate'}

_tinted: set[int] = set()
_titlebar_pending = False


def on_tab_bar_dirty(boss: Any, window: Any, data: dict[str, Any]) -> None:
    # Theme reloads and appearance switches dirty the tab bar even when hidden.
    # Kitty applies titlebar colors after notifying watchers, so wait for it.
    global _titlebar_pending
    if is_macos and not _titlebar_pending and get_options().macos_titlebar_color != 1:
        _titlebar_pending = True
        add_timer(_restore_titlebar, 0, False)


def _restore_titlebar(timer_id: int | None = None) -> None:
    global _titlebar_pending
    try:
        patch_colors({'macos_titlebar_color': 1}, configured=True)  # 1 = background
    finally:
        _titlebar_pending = False


def _argv_is_remote(argv: list[str]) -> bool:
    words = [w for w in argv if w]
    while words and (words[0] in WRAPPER_WORDS or ('=' in words[0] and not words[0].startswith('-'))):
        words = words[1:]
    if not words:
        return False
    prog = os.path.basename(words[0])
    if prog in REMOTE_PROGRAMS:
        return True
    return prog == 'kitten' and len(words) > 1 and words[1] == 'ssh'


def _cmdline_is_remote(cmdline: str) -> bool:
    try:
        return _argv_is_remote(shlex.split(cmdline))
    except ValueError:
        return _argv_is_remote(cmdline.split())


def _foreground_is_remote(window: Any) -> bool:
    child = getattr(window, 'child', None)
    if child is None:
        return False
    for proc in child.foreground_processes:
        if _argv_is_remote(list(proc.get('cmdline') or ())):
            return True
    return False


def _hex(rgb: tuple[int, int, int]) -> str:
    return '#{:02x}{:02x}{:02x}'.format(*rgb)


def _tint(window: Any) -> None:
    # Clear any override first so the blend starts from the theme background.
    window.set_dynamic_color(111)
    bg = window.screen.color_profile.default_bg
    base = (bg.red, bg.green, bg.blue)
    mixed = tuple(round(b + (t - b) * TINT_STRENGTH) for b, t in zip(base, TINT_TARGET))
    window.set_dynamic_color(11, _hex(mixed))  # type: ignore[arg-type]
    _tinted.add(window.id)


def _untint(window: Any) -> None:
    if window.id in _tinted:
        _tinted.discard(window.id)
        window.set_dynamic_color(111)


def _sync(window: Any) -> None:
    if _foreground_is_remote(window):
        if window.id not in _tinted:
            _tint(window)
    else:
        _untint(window)


def on_cmd_startstop(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if data.get('is_start') and window.id not in _tinted and _cmdline_is_remote(data.get('cmdline') or ''):
        _tint(window)
    wid = window.id

    def recheck(timer_id: int | None = None) -> None:
        w = boss.window_id_map.get(wid)
        if w is not None:
            _sync(w)

    if data.get('is_start'):
        # The start mark arrives before the shell forks; look again once the
        # command is actually running.
        add_timer(recheck, 0.5, False)
    else:
        recheck()


def on_color_scheme_preference_change(boss: Any, window: Any, data: dict[str, Any]) -> None:
    # A theme switch replaces the tint with the new plain background. Our own
    # escape-code changes arrive with via_escape_code=True and are ignored.
    if not data.get('via_escape_code') and window.id in _tinted:
        _tint(window)


def on_close(boss: Any, window: Any, data: dict[str, Any]) -> None:
    _tinted.discard(window.id)
