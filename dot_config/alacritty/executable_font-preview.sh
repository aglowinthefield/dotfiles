#!/usr/bin/env bash
#
# Alacritty Nerd Font previewer
# ─────────────────────────────
# Cycles the [font.normal] family in ~/.config/alacritty/alacritty.toml.
# Because Alacritty live-reloads its config, the running window redraws with
# each font instantly. A rich sample (letterforms, symbols, Nerd Font glyphs,
# powerline separators, box drawing, colored code) is printed each time so you
# can compare fonts in place and keep the one you like.
#
# Usage:
#   font-preview.sh              interactive previewer (run it inside Alacritty)
#   font-preview.sh --list       list installed Nerd Font Mono families
#   font-preview.sh --current    print the family currently set in the config
#   font-preview.sh "<family>"   set a family directly and exit
#   font-preview.sh --restore    restore the config from the .bak made at launch
#
# Note: Alacritty does not render ligatures, so -> => etc. stay as-is by design.

set -uo pipefail

CONFIG="$HOME/.config/alacritty/alacritty.toml"
BACKUP="$HOME/.config/alacritty/alacritty.toml.fontpreview.bak"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -f "$CONFIG" ] || die "no alacritty config at $CONFIG"
command -v fc-list >/dev/null 2>&1 || die "fc-list not found (brew install fontconfig)"

# Read the family currently set under [font.normal].
current_family() {
  awk '
    /^\[/            { sect = $0 }
    sect == "[font.normal]" && /^[[:space:]]*family[[:space:]]*=/ {
      if (match($0, /"[^"]*"/)) { print substr($0, RSTART + 1, RLENGTH - 2); exit }
    }' "$CONFIG"
}

# Replace the family under [font.normal] atomically (temp file + mv), so the
# live reload never sees a half-written config.
set_family() {
  local fam="$1" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/alacritty-font.XXXXXX")" || die "mktemp failed"
  awk -v fam="$fam" '
    /^\[/ { sect = $0 }
    {
      if (sect == "[font.normal]" && $0 ~ /^[[:space:]]*family[[:space:]]*=/)
        print "family = \"" fam "\""
      else
        print
    }' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# Load installed monospace Nerd Font families into FONTS[] (bash 3.2 friendly).
load_fonts() {
  FONTS=()
  while IFS= read -r line; do
    [ -n "$line" ] && FONTS+=("$line")
  done < <(fc-list : family \
             | tr ',' '\n' \
             | grep -iE 'nerd font mono$' \
             | sed 's/^[[:space:]]*//' \
             | sort -uf)
  [ "${#FONTS[@]}" -gt 0 ] || die "no 'Nerd Font Mono' families found (are Nerd Fonts installed?)"
}

# ── preview rendering ────────────────────────────────────────────────────────

render() {
  local fam="$1" idx="$2" total="$3"
  clear
  printf '\033[1;38;5;223m  ✦  Alacritty Nerd Font Previewer\033[0m\n'
  printf '\033[38;5;240m  ────────────────────────────────────────────────────────────────\033[0m\n'
  printf '   \033[1;38;5;108m%s\033[0m   \033[38;5;245m[%d / %d]\033[0m\n\n' "$fam" "$idx" "$total"
  printf '  \033[38;5;245mFont is applied live — judge it against your real terminal content.\033[0m\n\n'
}

prompt_line() {
  printf '\033[38;5;240m  ────────────────────────────────────────────────────────────────\033[0m\n'
  printf '  \033[38;5;245m[enter]\033[0m next  \033[38;5;245mp\033[0m prev  \033[38;5;245m#\033[0m jump  \033[38;5;245m/txt\033[0m filter  \033[38;5;245ml\033[0m list  \033[38;5;245mk\033[0m keep  \033[38;5;245mr\033[0m restore\n'
  printf '  \033[1;38;5;223m› \033[0m'
}

list_fonts() {
  local i cur
  cur="$(current_family)"
  for i in "${!FONTS[@]}"; do
    if [ "${FONTS[$i]}" = "$cur" ]; then
      printf '  \033[1;38;5;108m%3d ● %s\033[0m\n' "$((i + 1))" "${FONTS[$i]}"
    else
      printf '  \033[38;5;250m%3d   %s\033[0m\n' "$((i + 1))" "${FONTS[$i]}"
    fi
  done
}

# ── non-interactive modes ────────────────────────────────────────────────────

case "${1:-}" in
  --list)
    load_fonts; list_fonts; exit 0 ;;
  --current)
    current_family; exit 0 ;;
  --restore)
    [ -f "$BACKUP" ] || die "no backup at $BACKUP"
    cp "$BACKUP" "$CONFIG" && echo "restored $CONFIG from backup"; exit 0 ;;
  -h|--help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  '')
    : ;;  # interactive
  *)
    load_fonts
    set_family "$1"
    echo "set font.normal family to \"$1\""; exit 0 ;;
esac

# ── interactive previewer ────────────────────────────────────────────────────

load_fonts
cp "$CONFIG" "$BACKUP"            # safety net for the whole file
ORIG_FAMILY="$(current_family)"

# Start at the current font if it's in the list, else the first.
idx=0
for i in "${!FONTS[@]}"; do
  [ "${FONTS[$i]}" = "$ORIG_FAMILY" ] && { idx=$i; break; }
done

apply() { set_family "${FONTS[$idx]}"; }

apply
while :; do
  render "${FONTS[$idx]}" "$((idx + 1))" "${#FONTS[@]}"
  prompt_line
  IFS= read -r cmd || cmd="k"

  case "$cmd" in
    ''|n|N)             idx=$(( (idx + 1) % ${#FONTS[@]} )); apply ;;
    p|P)                idx=$(( (idx - 1 + ${#FONTS[@]}) % ${#FONTS[@]} )); apply ;;
    k|K|q|Q)            printf '\n  kept \033[1;38;5;108m%s\033[0m\n' "${FONTS[$idx]}"; break ;;
    r|R)                set_family "$ORIG_FAMILY"; printf '\n  restored \033[1;38;5;108m%s\033[0m\n' "$ORIG_FAMILY"; break ;;
    l|L)                clear; list_fonts; printf '\n  \033[38;5;245mpress enter to return\033[0m '; read -r _ ;;
    /*)                 # filter: jump to first family matching the text after /
      q="${cmd#/}"
      hit=-1
      for i in "${!FONTS[@]}"; do
        case "$(printf '%s' "${FONTS[$i]}" | tr 'A-Z' 'a-z')" in
          *"$(printf '%s' "$q" | tr 'A-Z' 'a-z')"*) hit=$i; break ;;
        esac
      done
      if [ "$hit" -ge 0 ]; then idx=$hit; apply
      else printf '  \033[38;5;168mno match for "%s"\033[0m ' "$q"; read -r _; fi ;;
    *[!0-9]*|'')        : ;;  # ignore junk
    *)                  # numeric jump
      if [ "$cmd" -ge 1 ] && [ "$cmd" -le "${#FONTS[@]}" ]; then
        idx=$((cmd - 1)); apply
      fi ;;
  esac
done
