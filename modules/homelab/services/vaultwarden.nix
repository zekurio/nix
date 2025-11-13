{ config
, lib
, ...
}: {
  options.services.vaultwarden-wrapped = {
    enable = lib.mkEnableOption "Vaultwarden password manager with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "vw.zekurio.xyz";
      description = "Domain name for Vaultwarden";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8222;
      description = "Port for Vaultwarden to listen on";
    };
  };

  config = lib.mkIf config.services.vaultwarden-wrapped.enable {
    services.vaultwarden = {
      enable = true;
      config = {
        DOMAIN = "https://${config.services.vaultwarden-wrapped.domain}";
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = config.services.vaultwarden-wrapped.port;
        WEBSOCKET_ENABLED = true;
        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = true;
      };
      environmentFile = config.sops.secrets.vaultwarden_env.path;
    };

    # SOPS secret for vaultwarden environment variables
    sops.secrets.vaultwarden_env = {
      owner = "vaultwarden";
      group = "vaultwarden";
      mode = "0400";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."vaultwarden" = {
      domain = config.services.vaultwarden-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.vaultwarden-wrapped.port}";
    };
  };
}
