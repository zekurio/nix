{
  config,
  lib,
  ...
}: let
  cfg = config.services.jellything-wrapped;
  domain = cfg.domain;
  port = 3010;
  containerPort = 3000;
  containerUser = "0:0";
in {
  options.services.jellything-wrapped = {
    enable = lib.mkEnableOption "Jellything invite service with Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "jt.schnitzelflix.xyz";
      description = "Public domain served by Caddy for Jellything.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.jellything = {
      image = "ghcr.io/zekurio/jellything:unstable";
      user = containerUser;
      ports = ["${toString port}:${toString containerPort}"];
      volumes = [
        "jellything_data:/app/data"
        "jellything_config:/app/config"
        "/var/lib/jellyfin:/jf:ro"
      ];
    };

    services.caddy-wrapper.virtualHosts."jellything" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
