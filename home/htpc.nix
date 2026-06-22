{ config, pkgs, lib, ... }:

{
  home.username = "htpc";
  home.homeDirectory = "/home/htpc";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # The two managed dotfiles. Source files live next to this one so they
  # can be edited and diff'd as plain text.
  home.file = {
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
