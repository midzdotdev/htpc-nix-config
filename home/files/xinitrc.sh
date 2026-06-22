#!/bin/bash

# Prevent screen blanking / power saving (stops TV going dark)
xset s off
xset -dpms
xset s noblank

# Hide the mouse cursor when idle
unclutter -idle 1 &

# HTPC-mode display: only use HDMI to the TV, ignore the built-in laptop
# screen. X.org syncs all page-flips to the primary CRTC; mixing two
# monitors at different refresh rates (eDP 120Hz vs HDMI 60Hz) causes
# the non-primary one to tear permanently. Single output = clean vsync.
xrandr --output HDMI-1 --primary --auto --output eDP-1 --off

# Give docker services (aiostreams, stremio-server) a moment to come up
sleep 4

openbox &
sleep 1

# Unified Remote server — phone-as-keyboard/D-pad over LAN
/opt/urserver/urserver-start --no-manager --no-notify &

# AirPlay 2 mirror receiver — iOS/macOS devices can cast to this box.
uxplay -n HTPC -nh -fs -vs glimagesink 2>&1 | logger -t uxplay &

# Launch Stremio in background so we can fullscreen it after window appears
flatpak run com.stremio.Stremio &
STREMIO_PID=$!

# Watchdog: Stremio demotes itself from fullscreen to maximized when its
# internal player closes a video. Re-apply fullscreen whenever we notice
# that. ~2s poll, <0.01% CPU.
(
  while kill -0 $STREMIO_PID 2>/dev/null; do
    if wmctrl -l 2>/dev/null | grep -qi stremio; then
      state=$(xprop -name 'Stremio - Freedom to Stream' _NET_WM_STATE 2>/dev/null)
      case "$state" in
        *_NET_WM_STATE_FULLSCREEN*) ;;
        *) wmctrl -r 'Stremio' -b add,fullscreen 2>/dev/null ;;
      esac
    fi
    sleep 2
  done
) &

wait $STREMIO_PID
