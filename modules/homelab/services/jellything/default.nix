{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.jellything;
  domain = cfg.domain;
  port = 4173;
  containerPort = 4173;
  containerUser = "0:0";
in {
  options.services.homelab.jellything = {
    enable = lib.mkEnableOption "Jellything invite service with Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "accounts.schnitzelflix.xyz";
      description = "Public domain served by Caddy for Jellything.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.jellything = {
      image = "ghcr.io/zekurio/jellything:unstable";
      user = containerUser;
      ports = ["${toString port}:${toString containerPort}"];
      volumes = [
        "/var/lib/jellything/data:/app/data"
        "/var/lib/jellything/config:/app/config"
        "/var/lib/jellyfin:/jf:ro"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/jellything 0755 root root -"
      "d /var/lib/jellything/data 0755 root root -"
      "d /var/lib/jellything/config 0755 root root -"
    ];

    services.homelab.caddy.virtualHosts."jellything" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
