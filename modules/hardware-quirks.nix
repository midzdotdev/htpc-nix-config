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
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  boot.kernelModules = [ "uinput" ];
}
