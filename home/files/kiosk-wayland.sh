#!/bin/bash
# Kiosk session under Cage (Wayland). Stremio v5 (the 1.x shell) fails to
# start its WebView on X11 — "TypeError: undefined is not a function",
# upstream stremio-bugs#2634 — in both the flatpak and native builds, so the
# whole session runs on Wayland instead. Wayland also gives per-output vsync,
# which X11 could not do while both the TV and the laptop panel were active.
#
# Cage runs exactly one client, so this wrapper starts the helpers in the
# background and leaves Stremio in the foreground: when Stremio exits, the
# session ends and the respawn loop in .bash_profile starts a fresh one.

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# TV only when it's plugged in: cage spans every connected output by default,
# which would stretch the UI across the TV and the laptop panel. The panel is
# left enabled when there is no TV so the box stays usable on its own.
(
  sleep 2
  if wlr-randr | grep -q '^HDMI-A-1'; then
    wlr-randr --output eDP-1 --off 2>/dev/null
  fi
) &

# Audio out over HDMI. The profile can read as "unavailable" until the TV's
# ELD arrives, so retry rather than assuming the first attempt sticks.
(
  for _ in $(seq 1 15); do
    pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:hdmi-stereo 2>/dev/null &&
      pactl set-default-sink alsa_output.pci-0000_00_1f.3.hdmi-stereo 2>/dev/null &&
      break
    sleep 1
  done
) &

# Unified Remote — phone as keyboard/D-pad. Injects via /dev/uinput, which is
# kernel-level and needs no display server. Watchdog: it dies silently every
# few days, and its own start script refuses to run while a stale pidfile
# points at any live PID.
(
  while :; do
    if ! ss -tln 2>/dev/null | grep -q ':9512 '; then
      rm -f "$HOME/.urserver/urserver.pid"
      /opt/urserver/urserver-start --no-manager --no-notify >/dev/null 2>&1
    fi
    sleep 30
  done
) &

# AirPlay receiver. waylandsink replaces glimagesink now there is no X server.
(
  while :; do
    /usr/local/bin/uxplay -n HTPC -nh -fs -ca -nofreeze -vs waylandsink 2>&1 | logger -t uxplay
    sleep 2
  done
) &

exec flatpak run com.stremio.Stremio
