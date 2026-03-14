{
  config,
  lib,
  ...
}: let
  cfg = config.services.seerr-wrapped;
  domain = "requests.schnitzelflix.xyz";
  port = 5055;
in {
  options.services.seerr-wrapped = {
    enable = lib.mkEnableOption "Seerr media request manager with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.seerr = {
      image = "ghcr.io/seerr-team/seerr:latest";
      ports = ["${toString port}:${toString port}"];
      environment = {
        LOG_LEVEL = "debug";
        TZ = "Europe/Vienna";
        PORT = toString port;
      };
      volumes = [
        "/var/lib/seerr:/app/config"
      ];
    };

    systemd.tmpfiles.rules = [
      # The image runs as node:node (1000:1000) and needs write access to /app/config.
      "d /var/lib/seerr 0755 1000 1000 -"
    ];

    # Allow the Podman bridge to reach local Sonarr/Radarr instances via host.containers.internal.
    networking.firewall.interfaces.podman0.allowedTCPPorts = [
      7878
      8989
    ];

    services.caddy-wrapper.virtualHosts."seerr" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
