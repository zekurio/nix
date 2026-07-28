{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "vw.${config.services.homelab.domains.zekurio}";
    port = 8222;
  in {
    options.services.homelab.vaultwarden = {
      enable = lib.mkEnableOption "Vaultwarden password manager with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.vaultwarden.enable {
      services.vaultwarden = {
        enable = true;
        domain = domain;
        environmentFile = config.sops.secrets.vaultwarden_env.path;
        config = {
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = port;
          SIGNUPS_ALLOWED = false;
          INVITATIONS_ALLOWED = true;
          WEBSOCKET_ENABLED = true;
          SMTP_HOST = "smtp.purelymail.com";
          SMTP_PORT = 465;
          SMTP_SECURITY = "force_tls";
          SMTP_FROM = "homelab@zekurio.me";
          SMTP_FROM_NAME = "Vaultwarden";
          SMTP_USERNAME = "homelab@zekurio.me";
        };
      };

      sops.secrets.vaultwarden_env = {
        owner = "vaultwarden";
        group = "vaultwarden";
        mode = "0400";
      };

      services.homelab.caddy.virtualHosts."vaultwarden" = {
        domain = domain;
        reverseProxy = "127.0.0.1:${toString port}";
        # /admin is gated by the admin oauth2-proxy instance (Pocket ID admin
        # group), mirroring the pass rule on the Pangolin edge. Everything
        # else stays on Vaultwarden's own auth so clients keep working.
        forwardAuth = config.services.homelab.oauth2-proxy.admin.forwardAuthAddress;
        authPaths = ["/admin" "/admin/*"];
      };

      services.homelab.newt.resources.vaultwarden = {
        displayName = "Vaultwarden";
        inherit domain;
        target = "127.0.0.1:${toString port}";
        sso = true;
        ssoRoles = ["Admins"];
        ssoPaths = ["/admin"];
      };
    };
  };
}
