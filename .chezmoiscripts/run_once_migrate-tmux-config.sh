#!/bin/sh
# Migration: remove old XDG_CONFIG_HOME tmux location
# tmux config now lives at ~/.tmux.conf with plugins in ~/.tmux/plugins/
rm -rf ~/.config/tmux
