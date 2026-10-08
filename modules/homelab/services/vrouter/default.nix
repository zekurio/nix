{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    ...
  }: let
    cfg = config.services.homelab.vrouter;
    domain = "vrouter.${config.services.homelab.domains.zekurio}";
    port = 8180;
    authPort = 4180;
  in {
    imports = [inputs.vrouter.nixosModules.default];

    options.services.homelab.vrouter = {
      enable = lib.mkEnableOption "vrouter with private Caddy access and Pocket ID login";
      adminGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["admin"];
        description = "Pocket ID groups allowed full control of vrouter accounts and keys.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.pocket-id.enable;
          message = "services.homelab.vrouter requires Pocket ID.";
        }
        {
          assertion = cfg.adminGroups != [];
          message = "services.homelab.vrouter.adminGroups must restrict dashboard access to at least one group.";
        }
      ];

      services.vrouter = {
        enable = true;
        inherit port;
        host = "127.0.0.1";
        publicUrl = "https://${domain}";
        externalAuth = true;
      };

      services.oauth2-proxy = {
        enable = true;
        provider = "oidc";
        oidcIssuerUrl = "https://auth.${config.services.homelab.domains.zekurio}";
        redirectURL = "https://${domain}/oauth2/callback";
        httpAddress = "127.0.0.1:${toString authPort}";
        upstream = ["http://127.0.0.1:${toString port}"];
        reverseProxy = true;
        trustedProxyIP = ["127.0.0.1"];
        passHostHeader = true;
        passBasicAuth = false;
        passAccessToken = false;
        requestLogging = false;
        scope = "openid profile email groups";
        # The group check below is mandatory; a verified email alone grants nothing.
        email.domains = ["*"];
        keyFile = config.sops.secrets.vrouter_oauth_env.path;
        cookie = {
          name = "__Host-vrouter";
          secure = true;
          httpOnly = true;
          expire = "8h";
          refresh = "15m";
        };
        extraConfig = {
          allowed-group = cfg.adminGroups;
          code-challenge-method = "S256";
          insecure-oidc-skip-nonce = false;
          skip-provider-button = true;
          cookie-samesite = "lax";
          # Expired dashboard requests get 401 instead of an HTML login page.
          api-route = ["^/api(?:/|$)"];
        };
      };

      systemd.services.oauth2-proxy = {
        after = ["pocket-id.service" "vrouter.service"];
        serviceConfig = {
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

      sops.secrets.vrouter_oauth_env = {
        # OAUTH2_PROXY_CLIENT_ID, OAUTH2_PROXY_CLIENT_SECRET,
        # and OAUTH2_PROXY_COOKIE_SECRET. Read by systemd as root.
        mode = "0400";
        restartUnits = ["oauth2-proxy.service"];
      };

      services.homelab.caddy.virtualHosts.vrouter = {
        inherit domain;
        public = false;
        extraConfig = ''
          handle /v1/* {
            reverse_proxy 127.0.0.1:${toString port}
          }
          handle {
            reverse_proxy 127.0.0.1:${toString authPort}
          }
        '';
      };
    };
  };
}
