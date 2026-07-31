# HTPC — session handoff

_Written 2026-07-25, evening. Supersedes the copy that lived in `/tmp` on the
Mac, which did not survive reboots and had the repo location wrong._

## Current state: working

Stremio 1.1.3 fullscreen on the TV under a Wayland kiosk at 125% UI scale, fan
silent, Unified Remote working from the phone, Torrentio installed. Verified
across a reboot.

| | |
|---|---|
| Reach it | `ssh htpc` (key auth, passwordless; `htpc`/`htpc` for sudo) |
| Network | Home / `192.168.0.220`; profiles saved for `SKY6DZKK`, the Huawei 5 GHz, and Cornwall Lodge — switch with `sudo nmtui` |
| Session | Cage (Wayland) → Stremio + uxplay + urserver + urclick-fix, all self-respawning |
| Fan / temp | ~0 RPM idle, 53 °C package |
| Config repo | **On the Mac** at `~/code/htpc-nix-config` → https://github.com/midzdotdev/htpc-nix-config |

The box itself is **not** managed by the flake yet — it is a hand-configured
Debian trixie install. The flake is written and now buildable in principle, but
applying it is still a separate project.

## The five things worth remembering

**Stremio v5 cannot run under X11 on this box.** Its WebView fails with
`TypeError: undefined is not a function`
([upstream #2634](https://github.com/Stremio/stremio-bugs/issues/2634)) and the
window renders solid black. Not a packaging problem — it reproduces on the
flatpak *and* the native `.deb`, and survives every WebKit/GL workaround.
Wayland is the fix, so X11 is gone entirely and must not come back. Rolling
back isn't an option either: flathub has garbage-collected v4's objects.

**The dormant NVIDIA MX550 was the fan.** With `nouveau` blacklisted nothing
binds the card, and the kernel leaves runtime PM at `on` for driverless devices
— so it sat fully powered while the CPU idled. A udev rule sets
`power/control=auto`, it reaches D3cold, and the fan stops (4750 → 0 RPM).
Confirmed still `suspended` after the latest reboot.

**Unified Remote's taps need `urclick-fix`.** urserver emits a tap as
`BTN_LEFT` down *and* up inside a single evdev frame — identical timestamp, no
`SYN_REPORT` between — and libinput collapses that to a no-op. The symptom is
diagnostic: taps do nothing while press-and-hold works, because holding
straddles two frames. `~/bin/urclick-fix.py` watches urserver's device
read-only and replays collapsed clicks properly framed on its own uinput
device. Three separate pieces are load-bearing and none is redundant:

1. the `uinput` module being loaded (`/etc/modules-load.d/uinput.conf`; it is
   `=m` and nothing else pulls it in),
2. the udev rule giving the node `input`-group access, and
3. `urclick-fix` itself.

Upstream's answer to Wayland is "use X11", which is unavailable here. Their
stated reason — that Wayland blocks input simulation — is also wrong for this
box: uinput is kernel-level and demonstrably works.

**The TV hotplugs, so output config must be re-applied, not set once.**
Switching the TV off or changing its input disconnects HDMI, and wlroots then
destroys and recreates `HDMI-A-1` with default settings — dropping the UI scale
back to 100%. Cage keeps running throughout, so nothing re-runs a one-shot
`wlr-randr`, and the failure is silent and delayed: the scale is correct for
hours, then quietly is not. `eDP-1` never shows the problem because an internal
panel does not hotplug. `kanshi` therefore owns the output layout
(`~/.config/kanshi/config`); it watches for output changes and re-applies the
matching profile. Verified by forcing a disconnect through
`/sys/class/drm/*/status` (`echo off`, then `echo detect`) and watching the
profile come back. Do not "simplify" this back into a `wlr-randr` call in the
kiosk script.

**Stremio left in the player with no TV pegs a core indefinitely.** Observed
after ~4 days: one Stremio process at 100% of a core with 46 hours of
accumulated CPU time, package at 85 C, fan at 4200 rpm — with the box otherwise
completely idle, the TV off, the network silent and the player merely *paused*.
Sending Escape did nothing; restarting Stremio cleared it instantly and dropped
RSS from 1.5 GB to 199 MB. The likely mechanism is the video render loop losing
its vsync source when the output disappears and spinning free, but that is not
proven — what is certain is the correlation with the TV being off, and that a
restart fixes it. `tv-off-hook.sh` now stops Stremio when HDMI goes away and
the kiosk loop will not restart it until a TV is back.

Two measurement traps cost real time here, both of which make the box look
innocent when it is not:

- **`ps -o pcpu` is an average over the process's whole lifetime, not
  instantaneous.** On a box up for days it barely moves, so a process pegging a
  core reads the same before and after a fix, and `ps --sort=-pcpu` ranks by
  accumulated time rather than current load. Use `top -bn2` and read the
  *second* iteration, or diff `utime+stime` from `/proc/<pid>/stat`.
- **`/sys/class/hwmon/hwmon*/temp1_input` does not mean the CPU.** The first
  glob match on this box is an unrelated sensor reading ~30 C cooler than the
  package. Read `coretemp` (`Package id 0`), `dell_ddv`'s `CPU` label, or
  `/sys/class/thermal/*/type` = `x86_pkg_temp`. Getting this wrong shows 54 C
  next to a 4200 rpm fan and makes the cooling look broken when it is working
  correctly.

## What changed this session

**AIOStreams removed, and the container runtime with it.** It had served zero
requests since 2026-05-16: `accessed_at` 70 days stale, empty cache and
analytics tables, and no Stremio profile referenced the addon — it was never
installed on the box it ran for. Its `BASE_URL` also still pointed at
`192.168.0.25`, a lease the box left long ago, so every URL it generated was
dead. With it gone nothing else wanted docker, so all seven docker packages,
`/var/lib/docker`, the apt repo, the `docker` group and the `docker0` bridge
went too — 2.04 GB reclaimed.

**UI scale to 125%.** Stremio has no interface-size setting, so this is
compositor-side: scale 1.25, giving a 1536x864 logical desktop on the 1080p
panel. Owned by kanshi, not a one-shot `wlr-randr` — see below.

**Unified Remote fixed** (see above).

**urserver pin corrected.** The flake pinned 3.13.0.2304-1 at a URL that
returns a hard 404 — the path uses the *build number* as the directory, not the
full version, and no `-1` suffix. It could never have built. Now pinned to
3.14.0.2574 with a real hash, which is both upstream's current build and what
the box runs, so a first rebuild no longer downgrades a working install.

**Torrentio installed** with the caller's quality/size filters
(`qualityfilter=…|limit=5|sizefilter=10GB`).

**Stremio is now stopped while no TV is attached.** kanshi's `panel` profile
runs `tv-off-hook.sh`, which debounces for 60 s (a TV input change also drops
HDMI, and that should not cost you your place) and then stops Stremio; the
kiosk loop gates on `tv-connected` so it does not immediately restart it.
Verified both ways: a 20 s disconnect leaves Stremio running, a real TV-off
stops it and it stays stopped, and it returns within ~30 s of the TV coming
back. Measured idle states, all three of which are **fan-silent**, so the
reason to stop Stremio is the memory and the runaway above, not noise:

| State | CPU | Fan | Package | RAM used |
|---|---|---|---|---|
| Runaway (the fault) | 100% of a core | 4201 rpm | 85 C | — |
| Stremio idle on dashboard | 1.4% | 0 rpm | 52 C | 4295 MB |
| Stremio stopped (chosen) | 0.0% | 0 rpm | 48 C | 710 MB |
| Whole session stopped | 0.0% | 0 rpm | 48 C | 623 MB |

Stopping the entire session was rejected on those numbers: it buys 87 MB over
just stopping Stremio, and costs the compositor, uxplay and — the deciding
factor — the planned wayvnc service, which is most wanted precisely when the TV
is off. It does not even stop urserver, which daemonises out of the session
cgroup and keeps running regardless.

## Next project: control the display from the laptop in a browser

Unified Remote's web UI is janky. The goal is a web service reachable from the
laptop that shows the screen and drives it.

### Recommendation: wayvnc + noVNC

wayvnc is the wlroots-native VNC server; noVNC (via websockify) puts it in a
browser so no VNC client is needed. **The feasibility question was already
checked** — the usual blocker is a kiosk compositor not exposing the protocols
a VNC server needs, and Cage exposes all of them:

```
wlr_screencopy_manager_v1_create        # screen capture
wlr_virtual_keyboard_manager_v1_create  # keyboard injection
wlr_virtual_pointer_manager_v1_create   # pointer injection
```

so wayvnc should get both view *and* input with no custom code. Everything is
packaged in Debian trixie (`wayvnc 0.9.1-1`, `novnc 1:1.6.0-2`,
`websockify 0.12.0`) and present in nixpkgs for when the flake goes live.

Rough shape:

1. `wayvnc` bound to localhost on 5900, started from `kiosk-wayland.sh` as
   another watchdogged helper (it needs `WAYLAND_DISPLAY`, like `grim`).
2. `websockify` serving noVNC on 6080 → `http://htpc.local:6080/vnc.html`.
3. Open 6080 in the firewall (and 5900 only if a native client is wanted).
4. Mirror into the flake: packages, the kiosk script, firewall ports.

Things to decide or watch:

- **Auth.** wayvnc supports TLS and username/password but needs a cert and a
  credentials file. Even on the LAN this is a service that grants full control
  of the box, so it should not be wide open — and the secret belongs in agenix
  rather than the repo.
- **Performance.** Fine for driving the UI; do not expect to watch video
  through it. Damage-tracked screencopy over Wi-Fi at 1080p is adequate for
  clicking around, no more. Consider capping the frame rate.
- **Injection path is independent** of `urclick-fix`: wayvnc injects at the
  compositor level via the virtual-pointer/keyboard protocols, not through
  `/dev/uinput`, so the two cannot conflict.
- **Cage's clipboard.** Cage never creates a data-control manager and only
  hands the selection to the focused client, so `wl-copy`/`wl-paste` do not
  work here at all (verified — `wl-paste` returns nothing). Do not plan on
  copy/paste between laptop and box via the clipboard; noVNC's own clipboard
  panel goes through the VNC protocol and may work, but it is untested.

### Alternatives considered

| Option | Verdict |
|---|---|
| **wayvnc + noVNC** | Recommended. Standard, packaged, browser-native, view + input, no custom code. |
| Custom web pad over `/dev/uinput` | Viable fallback and very light — a control pad plus periodic `grim` screenshots. Only worth it if wayvnc's input path disappoints, since it is code to maintain. The uinput approach is proven on this box. |
| Sunshine + Moonlight | Built for game streaming. Better video, but not browser-based and far more than this needs. |
| `wlrctl` / a thin HTTP wrapper | Simplest possible, but gives no view of the screen — which is most of the point. |

## Operating it

- Text console: **Ctrl+Alt+F2** (kernel VT). **Ctrl+Alt+F1** returns to the kiosk.
- Screenshot remotely:
  `ssh htpc "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/s.png"`
  then `scp htpc:/tmp/s.png .`
- Logs: `/tmp/stremio.log`, `/tmp/cage.log`, `journalctl -t uxplay`,
  `journalctl -t urclick-fix`, `~/.urserver/urserver.log`
- Restart the kiosk: `sudo systemctl restart getty@tty1`
- Unified Remote: iOS app, or `http://htpc.local:9530/client/`
- Driving the UI headlessly is awkward without a keyboard on the box. Two traps
  worth knowing if you script it again: libinput applies pointer acceleration
  so *relative* motion cannot target precisely — use an absolute device
  (`ABS_X`/`ABS_Y` + `INPUT_PROP_DIRECT`) — and the kernel silently discards
  events for any key code not declared with `UI_SET_KEYBIT` before
  `UI_DEV_CREATE`, so a partially-declared device types only some characters
  and drops the rest with no error anywhere.

## Known risks / open items

- **The flake is still not applied.** `hosts/htpc/hardware.nix` is a
  placeholder, so it cannot be installed as-is. The urserver derivation should
  now build, but has not been built — no x86_64-linux machine to try it on.
- **The Stremio flatpak auto-updates**, and a release could regress. The
  session self-respawns, so a bad update shows as a black or missing UI rather
  than a crash loop. `--no-window-decorations` and the uxplay flags are all
  upstream-supported.
- **Wi-Fi credentials** are still not codified — agenix or a one-time `nmcli`
  after install.
- **urserver is pinned to a build upstream will eventually delete.** They
  garbage-collect old builds, which is what broke the previous pin. If the
  fetch 404s, that means "find the new build", not "the hash is wrong": resolve
  `https://www.unifiedremote.com/download/linux-x64-portable` and
  `nix-prefetch-url` the target.
