#!/bin/bash

# Prevent screen blanking / power saving (stops TV going dark)
xset s off
xset -dpms
xset s noblank

# Hide the mouse cursor when idle
unclutter -idle 1 &

# Display layout:
#   - HDMI + eDP: TV shows Stremio/AirPlay (primary, tear-free), laptop
#     panel shows a terminal on the right. Both forced to 60Hz to keep the
#     refresh-rate mismatch (eDP native 120Hz vs HDMI 60Hz) from tearing
#     the secondary output.
#   - eDP only: single output, standard.
if xrandr | grep -q '^HDMI-1 connected'; then
  xrandr --output HDMI-1 --primary --mode 1920x1080 --rate 60 --pos 0x0 \
         --output eDP-1 --mode 1920x1080 --rate 60 --pos 1920x0
  # Terminal on the built-in laptop panel (eDP-1 spans x=1920..3839).
  (sleep 3; xterm -geometry 130x40+1970+80 -fa Monospace -fs 12 -T Terminal >/dev/null 2>&1 &) &
else
  xrandr --output eDP-1 --primary --auto --output HDMI-1 --off
fi

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
