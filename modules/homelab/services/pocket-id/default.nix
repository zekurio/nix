{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "auth.${config.services.homelab.domains.zekurio}";
    port = 1411;
  in {
    options.services.homelab.pocket-id = {
      enable = lib.mkEnableOption "Pocket ID authentication server with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.pocket-id.enable {
      services.pocket-id = {
        enable = true;
        settings = {
          APP_URL = "https://${domain}";
          TRUST_PROXY = true;
          PORT = port;
          HOST = "127.0.0.1";
        };
        environmentFile = config.sops.secrets.pocket_id_env.path;
      };

      sops.secrets.pocket_id_env = {
        owner = config.services.pocket-id.user;
        group = config.services.pocket-id.group;
        mode = "0400";
      };

      services.homelab.caddy.virtualHosts."pocket-id" = {
        domain = domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
