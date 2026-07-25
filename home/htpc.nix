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

    # X11 fallback (KIOSK=x11 at login). Stremio v5 shows a black window
    # here — see the note in the file — so this is recovery only.
    ".xinitrc" = {
      source = ./files/xinitrc.sh;
      executable = true;
    };

    ".config/openbox/rc.xml".source = ./files/openbox-rc.xml;

    # Autostart entry for urserver, in case .xinitrc launch ever fails.
    ".config/autostart/urserver.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Unified Remote Server
      Exec=urserver-start --no-manager --no-notify
      X-GNOME-Autostart-enabled=true
    '';
  };
}
