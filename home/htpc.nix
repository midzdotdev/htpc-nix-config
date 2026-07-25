{ config, pkgs, lib, ... }:

{
  home.username = "htpc";
  home.homeDirectory = "/home/htpc";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # Managed dotfiles. Source files live next to this one so they can be
  # edited and diff'd as plain text.
  home.file = {
    # Login entry point: starts the Cage (Wayland) kiosk on tty1.
    ".bash_profile".source = ./files/bash_profile;

    # The Wayland session: Stremio + uxplay + urserver under Cage.
    "bin/kiosk-wayland.sh" = {
      source = ./files/kiosk-wayland.sh;
      executable = true;
    };

    # Works around urserver emitting tap clicks in a single evdev frame, which
    # libinput drops. See the header in the script.
    "bin/urclick-fix.py" = {
      source = ./files/urclick-fix.py;
      executable = true;
    };

  };
}
