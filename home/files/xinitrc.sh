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

# Force audio out over HDMI. The HDMI profile can be reported as
# "unavailable" by ALSA at boot before the TV's ELD is picked up, so retry
# for up to ~15s until it takes.
(
  for i in $(seq 1 15); do
    pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:hdmi-stereo 2>/dev/null && \
      pactl set-default-sink alsa_output.pci-0000_00_1f.3.hdmi-stereo 2>/dev/null && \
      break
    sleep 1
  done
) &

# Give docker services (aiostreams, stremio-server) a moment to come up
sleep 4

openbox &
sleep 1

# Unified Remote server — phone-as-keyboard/D-pad over LAN.
# Watchdog: urserver dies silently every few days (upstream bug, no error
# in logs). Poll port 9512 every 30s and restart if it stops answering. The
# stale-pidfile removal is essential — urserver-start refuses to launch if
# the pidfile points at any live PID, including one that got recycled.
(
  while :; do
    if ! ss -tln 2>/dev/null | grep -q ':9512 '; then
      rm -f ~/.urserver/urserver.pid
      /opt/urserver/urserver-start --no-manager --no-notify >/dev/null 2>&1
    fi
    sleep 30
  done
) &

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
