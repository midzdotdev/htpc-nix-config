# htpc-nix-config

Declarative NixOS configuration for the Stremio kiosk HTPC.

## Layout

```
flake.nix                       # inputs + nixosConfigurations.htpc
hosts/htpc/
  default.nix                   # host wiring
  hardware.nix                  # REPLACE on first install
modules/
  kiosk.nix                     # autologin → startx → openbox + Stremio
  services.nix                  # docker stacks, urserver-web-proxy, urserver pkg
  hardware-quirks.nix           # nouveau + bluetooth blacklist, uinput udev
home/
  htpc.nix                      # home-manager profile for the htpc user
  files/
    xinitrc.sh                  # kiosk launcher (Stremio fullscreen watchdog)
    openbox-rc.xml              # openbox config with Stremio + uxplay rules
```

## First install

1. Boot the HTPC from a NixOS ISO, partition, mount at `/mnt`.
2. Generate hardware config on the target:
   ```
   nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw.nix
   ```
3. Copy `/tmp/hw.nix` over `hosts/htpc/hardware.nix` in this repo.
4. `nix-prefetch-url` the urserver tarball URL in `modules/services.nix`,
   paste the resulting hash into the `sha256` field (replacing `lib.fakeSha256`).
5. Install:
   ```
   nixos-install --flake .#htpc
   ```
6. Reboot. The kiosk should come up on tty1 → Stremio fullscreen.

## Subsequent rebuilds

From the Mac:
```
nixos-rebuild switch --flake .#htpc --target-host htpc@htpc.local --use-remote-sudo
```

From the box itself:
```
sudo nixos-rebuild switch --flake .#htpc
```

## Things not yet codified (intentionally)

- **Wi-Fi credentials.** Don't commit secrets. Either set up `agenix` and
  encrypt with the existing `id_ed25519_agenix` key, or pass them via
  NetworkManager once after install with `nmcli`.
- **AIOStreams `SECRET_KEY`.** Same — replace with agenix when ready.
- **Stremio user account.** Login is per-device state, not config.
- **Stremio library / addon list.** Synced via the Stremio account.
