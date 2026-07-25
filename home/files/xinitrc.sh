#!/bin/bash

# Prevent screen blanking / power saving (stops TV going dark)
xset s off
xset -dpms
xset s noblank

# Hide the mouse cursor when idle
unclutter -idle 1 &

# Display layout: single output only. Two active outputs run on independent
# pixel clocks and disturb GL frame pacing, so the kiosk uses just the TV
# when it's connected. Ctrl+Alt+T toggles the laptop panel + a terminal on
# it as a fallback console (see ~/bin/terminal-display.sh).
if xrandr | grep -q '^HDMI-1 connected'; then
  xrandr --output HDMI-1 --primary --mode 1920x1080 --rate 60 --pos 0x0 \
         --output eDP-1 --off
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
# -ca renders cover art + track metadata for audio-only (Spotify/Music)
# sessions; -nofreeze closes the video window when a client vanishes
# instead of leaving a stale frozen frame over the kiosk.
# Respawn loop: uxplay exits when avahi restarts (e.g. during upgrades)
# and occasionally on client-side aborts; relaunch it like urserver.
(
  while :; do
    /usr/local/bin/uxplay -n HTPC -nh -fs -ca -nofreeze -vs glimagesink 2>&1 | logger -t uxplay
    sleep 2
  done
) &

# Watchdog: re-assert fullscreen whenever Stremio drops out of it.
(
  while :; do
    win=$(wmctrl -lx 2>/dev/null | awk '$3 ~ /stremio/ {print $1; exit}')
    if [ -n "$win" ]; then
      case "$(xprop -id "$win" _NET_WM_STATE 2>/dev/null)" in
        *_NET_WM_STATE_FULLSCREEN*) ;;
        *) wmctrl -i -r "$win" -b add,fullscreen 2>/dev/null ;;
      esac
    fi
    sleep 2
  done
) &

# NOTE: this X11 session is the fallback path only (KIOSK=x11 at login).
# Stremio v5 cannot start its WebView under X11 on this box, so it will show
# a black window here — the Wayland session in ~/bin/kiosk-wayland.sh is the
# working one. Kept for recovery if Cage ever fails to start.
#
# Respawn loop: a crash must not end xinit and drop the TV to a console.
while :; do
  flatpak run com.stremio.Stremio >>/tmp/stremio.log 2>&1
  sleep 3
done
