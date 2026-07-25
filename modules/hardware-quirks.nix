{ config, pkgs, lib, ... }:

{
  # Dormant NVIDIA MX550. nouveau's GSP support for Turing is broken; any
  # process that opens /dev/dri/card1 (rustdesk, OBS, etc) triggers an
  # endless wake/fail loop that pegs the fan. Keep the dGPU invisible.
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"

    # No Bluetooth use case on this box.
    "btusb"
    "btintel"
    "btbcm"
    "btrtl"
    "btmtk"
    "bluetooth"
  ];

  # Intel iGPU only.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Unified Remote's Media agent uses /dev/uinput to inject keypresses.
  # Default perms are root-only; give the input group write access.
  #
  # The PCI rule is about heat: with nouveau blacklisted nothing binds the
  # MX550, and the kernel leaves runtime PM at "on" for driverless devices —
  # so the card sat fully powered doing nothing. The fan ran at ~4750 RPM to
  # shift that heat even with the CPU 95% idle. Setting "auto" lets it reach
  # D3cold, after which the fan stops entirely.
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';

  boot.kernelModules = [ "uinput" ];
}
