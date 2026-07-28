{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "docs.${config.services.homelab.domains.zekurio}";
    port = 8010;
  in {
    options.services.homelab.paperless-ngx = {
      enable = lib.mkEnableOption "Paperless-ngx document management system with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.paperless-ngx.enable {
      services.paperless = {
        enable = true;
        dataDir = "/var/lib/paperless";
        consumptionDir = "/var/lib/paperless/consume";
        consumptionDirIsPublic = true;
        port = port;
        address = "127.0.0.1";
        environmentFile = config.sops.secrets.paperless_env.path;
        settings = {
          PAPERLESS_URL = "https://${domain}";
          PAPERLESS_DISABLE_REGULAR_LOGIN = true;
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          PAPERLESS_TIME_ZONE = config.time.timeZone;
          PAPERLESS_ENABLE_COMPRESSION = true;
          PAPERLESS_TASK_WORKERS = 2;
          PAPERLESS_CONSUMER_IGNORE_PATTERN = [
            ".DS_STORE/*"
            "desktop.ini"
          ];
        };
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/paperless/consume 0770 paperless paperless -"
      ];

      services.homelab.caddy.virtualHosts."paperless-ngx" = {
        domain = domain;
        reverseProxy = "127.0.0.1:${toString port}";
        # /admin is gated by the admin oauth2-proxy instance (Pocket ID admin
        # group), mirroring the pass rule on the Pangolin edge. Everything
        # else keeps Paperless' own login.
        forwardAuth = config.services.homelab.oauth2-proxy.admin.forwardAuthAddress;
        authPaths = ["/admin" "/admin/*"];
      };

      services.homelab.newt.resources.paperless = {
        displayName = "Paperless";
        inherit domain;
        target = "127.0.0.1:${toString port}";
        sso = true;
        ssoRoles = ["Admins"];
        ssoPaths = ["/admin"];
      };

      users.users.paperless.extraGroups = ["share"];

      sops.secrets.paperless_env = {
        owner = "paperless";
        group = "paperless";
        mode = "0400";
      };
    };
  };
}
