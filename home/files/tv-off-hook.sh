#!/bin/bash
# Run by kanshi when the "panel" profile is applied — i.e. the TV disconnected.
#
# Stremio is stopped rather than left running. Left alone with no TV, a paused
# player pegged a core for days: 46 hours of accumulated CPU time, one core at
# 100%, package at 85 C and the fan at 4200 rpm, with the box otherwise idle.
# A restart cleared it instantly. The kiosk loop will not start Stremio again
# until a TV is back (see tv-connected), so the box drops to ~0% CPU and 710 MB.
#
# Measured, so nobody has to re-derive it: idling on the dashboard with no TV
# costs 1.4% CPU / 52 C / 4295 MB, and stopping Stremio gives 0.0% / 48 C /
# 710 MB. Both are fan-silent. The reason to stop it is the 3.6 GB and the
# runaway, not noise.
#
# Debounce first: changing the TV's input drops HDMI briefly too, and that
# should not cost you your place in an episode.

DEBOUNCE=${TV_OFF_DEBOUNCE:-60}

# kanshi can apply a profile more than once; only let one hook wait at a time.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tv-off-hook.lock"
flock -n 9 || exit 0

sleep "$DEBOUNCE"

if "$HOME/bin/tv-connected"; then
	logger -t tv-off-hook "TV back within ${DEBOUNCE}s — leaving Stremio running"
	exit 0
fi

logger -t tv-off-hook "TV still gone after ${DEBOUNCE}s — stopping Stremio"
flatpak kill com.stremio.Stremio
