{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.seerr;
  domain = "requests.schnitzelflix.xyz";
  port = 5055;
  stateDir = "/var/lib/seerr";
in {
  options.services.homelab.seerr = {
    enable = lib.mkEnableOption "Seerr media request manager with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.seerr = {
      enable = true;
      inherit port;
      configDir = stateDir;
    };

    systemd.services.seerr = {
      environment = {
        LOG_LEVEL = "debug";
        TZ = "Europe/Vienna";
      };
      serviceConfig.StateDirectory = lib.mkForce "seerr";
    };

    services.homelab.caddy.virtualHosts."seerr" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
