{ config, pkgs, lib, ... }:

{
  # Autologin htpc on tty1 → ~/.bash_profile auto-runs startx → .xinitrc
  # spawns openbox + stremio + uxplay + urserver.
  services.getty.autologinUser = "htpc";

  services.xserver = {
    enable = true;
    autorun = false;
    displayManager.startx.enable = true;

    windowManager.openbox.enable = true;

    xkb.layout = "gb";
  };

  # Sound stack.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # Auto-start startx when logging into tty1 (only tty1, so SSH sessions don't
  # try to launch X).
  programs.bash.loginShellInit = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec startx
    fi
  '';

  environment.systemPackages = with pkgs; [
    # X session helpers used in .xinitrc
    xorg.xrandr
    xorg.xset
    xorg.xprop
    xorg.xauth
    wmctrl
    unclutter
    xterm

    # Media / kiosk apps
    stremio
    uxplay

    # Diagnostics (we use these constantly when poking at the box)
    htop
    iotop
    pciutils
    usbutils
    lm_sensors
    strace
    socat
    sshpass
    git
    vim
    curl
    jq
  ];
}
