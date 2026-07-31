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

# Output layout (which outputs are on, and the 125% scale) lives in
# ~/.config/kanshi/config. kanshi rather than a one-shot wlr-randr because the
# TV hotplugs: switching it off or changing its input disconnects HDMI, and
# wlroots then recreates the output with default settings. Cage keeps running
# throughout, so nothing re-ran the old wlr-randr block and the UI silently
# dropped back to 100%. kanshi watches for output changes and re-applies.
(
  while :; do
    kanshi 2>&1 | logger -t kanshi
    sleep 5
  done
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

# urserver emits a tap as BTN_LEFT down+up inside one evdev frame, which
# libinput collapses to nothing: taps do nothing while hold-to-drag works.
# This replays those collapsed clicks properly framed. It re-attaches on its
# own when urserver restarts, so it only needs the outer respawn for crashes.
(
  while :; do
    "$HOME/bin/urclick-fix.py" 2>&1 | logger -t urclick-fix
    sleep 5
  done
) &

# AirPlay receiver. waylandsink replaces glimagesink now there is no X server.
(
  while :; do
    /usr/local/bin/uxplay -n HTPC -nh -fs -ca -nofreeze -vs waylandsink 2>&1 | logger -t uxplay
    sleep 2
  done
) &

# Stremio in the foreground, respawned in place. Cage exits when its client
# exits, so looping here (rather than exec'ing) keeps the compositor and the
# helpers above alive across a Stremio crash instead of rebuilding the whole
# session. The outer loop in .bash_profile covers Cage itself dying.
#
# --no-window-decorations drops the GTK headerbar, so the UI fills the TV.
# Stremio's own fullscreen toggle is not remembered between launches, which
# is why this flag rather than the in-app button.
#
# Only run Stremio while a TV is attached. With no TV there is nothing to
# display and a left-open player has pegged a core for days, so the box is
# better off idle — tv-off-hook.sh stops Stremio when HDMI goes away, and this
# gate keeps the loop from immediately starting it again. Polling rather than
# waiting on an event so that a TV coming back is picked up within a few
# seconds even if the hook missed a transition.
while :; do
  if "$HOME/bin/tv-connected"; then
    flatpak run com.stremio.Stremio --no-window-decorations >>/tmp/stremio.log 2>&1
  fi
  sleep 3
done
