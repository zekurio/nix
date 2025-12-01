{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Generate the base config file with placeholders
  dexConfig = pkgs.writeText "dex-config.yaml" ''
    issuer: https://${config.services.dex-wrapped.domain}
    web:
      http: 127.0.0.1:${toString config.services.dex-wrapped.port}
    storage:
      type: sqlite3
      config:
        file: /var/lib/dex/dex.db
    oauth2:
      skipApprovalScreen: true
      alwaysShowLoginScreen: false
    connectors:
      - type: google
        id: google
        name: Google
        config:
          clientID: $GOOGLE_CLIENT_ID
          clientSecret: $GOOGLE_CLIENT_SECRET
          redirectURI: https://${config.services.dex-wrapped.domain}/callback
    staticClients:
      - id: zekurio-services
        secret: $DEX_CLIENT_SECRET
        name: "services - zekurio.xyz"
        redirectURIs:
          - https://photos.zekurio.xyz/auth/login
          - https://photos.zekurio.xyz/user-settings
          - https://photos.zekurio.xyz/api/oauth/mobile-redirect
          - app.immich:///oauth-callback
          - https://docs.zekurio.xyz/callback
      - id: schnitzelflix-services
        secret: $DEX_CLIENT_SECRET
        name: "services - schnitzelflix.xyz"
        redirectURIs:
          - https://schnitzelflix.xyz/callback
          - https://jellyfin.schnitzelflix.xyz/callback
          - https://jellyseerr.schnitzelflix.xyz/callback
          - https://arr.schnitzelflix.xyz/callback
  '';
in
{
  options.services.dex-wrapped = {
    enable = lib.mkEnableOption "Dex OIDC provider with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.zekurio.xyz";
      description = "Primary domain name for Dex";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5556;
      description = "Port for Dex to listen on";
    };
  };

  config = lib.mkIf config.services.dex-wrapped.enable {
    # Create dex user and group
    users.users.dex = {
      isSystemUser = true;
      group = "dex";
      home = "/var/lib/dex";
    };
    users.groups.dex = { };

    systemd.services.dex = {
      description = "Dex OIDC Provider";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "dex";
        Group = "dex";
        StateDirectory = "dex";
        RuntimeDirectory = "dex";
        EnvironmentFile = config.sops.secrets.dex_env.path;

        # Use envsubst to expand environment variables in config
        ExecStartPre = "${pkgs.writeShellScript "dex-prepare-config" ''
          set -euo pipefail
          ${pkgs.envsubst}/bin/envsubst < ${dexConfig} > /run/dex/config.yaml
          chmod 600 /run/dex/config.yaml
        ''}";

        ExecStart = "${pkgs.dex-oidc}/bin/dex serve /run/dex/config.yaml";
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "/var/lib/dex"
          "/run/dex"
        ];
      };
    };

    # SOPS secret for Dex environment file
    # Required variables:
    #   GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
    #   GOOGLE_CLIENT_SECRET=GOCSPX-xxx
    #   DEX_CLIENT_SECRET=<random-secret>
    sops.secrets.dex_env = {
      owner = "dex";
      group = "dex";
      mode = "0400";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."dex" = {
      domain = config.services.dex-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.dex-wrapped.port}";
    };
  };
}
