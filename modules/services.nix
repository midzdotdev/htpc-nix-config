{ config, pkgs, lib, ... }:

let
  # urserver (Unified Remote daemon) — closed source, distributed as a .deb.
  # Not in nixpkgs; pin the upstream tarball and unpack into the store.
  urserver = pkgs.stdenv.mkDerivation rec {
    pname = "urserver";
    version = "3.13.0.2304-1";

    src = pkgs.fetchurl {
      url = "https://www.unifiedremote.com/static/builds/server/linux-x64/${version}/urserver-${version}.tar.gz";
      # nix-prefetch-url the above to fill this in:
      sha256 = lib.fakeSha256;
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [ stdenv.cc.cc.lib zlib ];

    installPhase = ''
      mkdir -p $out/opt/urserver
      cp -r * $out/opt/urserver/
      mkdir -p $out/bin
      ln -s $out/opt/urserver/urserver-start $out/bin/urserver-start
    '';

    meta.description = "Unified Remote server";
  };
in
{
  # Docker for the AIOStreams + stremio-server stacks.
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # AIOStreams (port 3000) + stremio-server (host network).
  # The compose files live in the repo; bind-mount them in.
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    aiostreams = {
      image = "ghcr.io/viren070/aiostreams:latest";
      ports = [ "3000:3000" ];
      environment = {
        SECRET_KEY = "REPLACE_ME";  # rotate via agenix when set up
        BASE_URL = "http://htpc.local:3000";
      };
      volumes = [
        "/var/lib/htpc/aiostreams:/app/data"
      ];
      extraOptions = [ "--dns=1.1.1.1" "--dns=192.168.0.1" ];
    };

    stremio-server = {
      image = "stremio/server:latest";
      extraOptions = [ "--network=host" ];
      volumes = [
        "/var/lib/htpc/stremio-server:/root/.stremio-server"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/htpc 0755 root root - -"
    "d /var/lib/htpc/aiostreams 0755 root root - -"
    "d /var/lib/htpc/stremio-server 0755 root root - -"
  ];

  # urserver itself runs from .xinitrc (it needs X). All we expose here is
  # the LAN-visible web-UI proxy on :9530 → 127.0.0.1:9510.
  systemd.services.urserver-web-proxy = {
    description = "Expose Unified Remote web UI on the LAN";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.socat}/bin/socat TCP6-LISTEN:9530,fork,reuseaddr,ipv6only=0 TCP:127.0.0.1:9510";
      Restart = "on-failure";
      RestartSec = "3";
    };
  };

  # Ports we own.
  networking.firewall.allowedTCPPorts = [
    22       # ssh
    3000     # aiostreams
    9530     # unified remote web UI proxy
    9510     # unified remote (local only, but firewall would block xdg LAN clients)
    9512     # unified remote binary protocol
    11470    # stremio-server http
    11471    # stremio-server https
    12470    # stremio-server peer
    40719    # uxplay control
    7000     # uxplay airplay
    7001     # uxplay airplay
  ];
  networking.firewall.allowedUDPPorts = [
    5353     # mDNS
    7011     # uxplay airplay
    6000 6001 6002  # uxplay raop
  ];

  # urserver as a package — referenced by .xinitrc via PATH or absolute path.
  environment.systemPackages = [ urserver ];
}
