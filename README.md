# htpc-nix-config

Declarative NixOS configuration for the Stremio kiosk HTPC.

## Layout

```
flake.nix                       # inputs + nixosConfigurations.htpc
hosts/htpc/
  default.nix                   # host wiring
  hardware.nix                  # REPLACE on first install
modules/
  kiosk.nix                     # autologin → Cage (Wayland) + Stremio
  services.nix                  # urserver-web-proxy, urserver pkg, firewall ports
  hardware-quirks.nix           # nouveau + bluetooth blacklist, uinput udev
home/
  htpc.nix                      # home-manager profile for the htpc user
  files/
    bash_profile                # starts Cage on tty1 login
    kiosk-wayland.sh            # kiosk launcher (Stremio/uxplay/urserver watchdogs)
```

## First install

1. Boot the HTPC from a NixOS ISO, partition, mount at `/mnt`.
2. Generate hardware config on the target:
   ```
   nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw.nix
   ```
3. Copy `/tmp/hw.nix` over `hosts/htpc/hardware.nix` in this repo.
4. Install:
   ```
   nixos-install --flake .#htpc
   ```
5. Reboot. The kiosk should come up on tty1 → Stremio fullscreen.

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
- **Stremio user account.** Login is per-device state, not config.
- **Stremio library / addon list.** Synced via the Stremio account.
