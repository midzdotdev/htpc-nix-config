#!/bin/bash
# Fallback console: toggle the laptop panel + a terminal on it.
# Bound to Ctrl+Alt+T in openbox — usable from the built-in keyboard even
# when SSH and Unified Remote are down. The kiosk normally runs single-output
# (HDMI only) because a second display clock disturbs frame pacing.
if xrandr --listmonitors | grep -q eDP-1; then
  pkill -x xterm 2>/dev/null
  xrandr --output eDP-1 --off
else
  xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 1920x0
  sleep 1
  xterm -geometry 130x40+1970+80 -fa Monospace -fs 12 -T Terminal &
fi
