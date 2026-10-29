#!/usr/bin/env bash
# tmux-dotbar labels ssh windows from the remote's pane title, which is the
# remote window title. A Windows host sends "Administrator: C:\...", so the tab
# read "Administrator". Feed the dotbar parser the local ssh command line
# ("ssh tom@heart") instead, so the tab shows the host we connected to.
new='"$(ps -o args= -p $(pgrep -P #{pane_pid} -x ssh | head -1))"'
for opt in window-status-format window-status-current-format; do
  v=$(tmux show -gv "$opt")
  tmux set -g "$opt" "${v//"'#{pane_title}'"/$new}"
done
