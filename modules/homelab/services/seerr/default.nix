{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.seerr;
    domain = "requests.${config.services.homelab.domains.schnitzelflix}";
    port = 5055;
    stateDir = "/var/lib/seerr";
  in {
    options.services.homelab.seerr = {
      enable = lib.mkEnableOption "Seerr media request manager with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}";
        description = "URL other services use to reach the Seerr API.";
      };
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
          TZ = config.time.timeZone;
        };
        serviceConfig.StateDirectory = lib.mkForce "seerr";
      };

      services.homelab.caddy.virtualHosts."seerr" = {
        inherit domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
