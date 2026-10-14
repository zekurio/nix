{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    # Mirrors the Traefik labels in upstream's docker-compose.yml. The
    # scanner reaches the API through this router too, because only
    # forward_auth turns its API key into the JWT the API checks.
    caddyfile = pkgs.writeText "kyoo-Caddyfile" ''
      {
        admin off
        auto_https off
        persist_config off
      }

      (cors) {
        header {
          Access-Control-Allow-Origin *
          Access-Control-Allow-Methods "GET, OPTIONS"
          Access-Control-Allow-Headers "Authorization, Content-Type, Range, X-Api-Key"
          +Vary Origin
        }
      }

      # Keibi validates the session, API key or presigned URL
      # (X-Forwarded-Uri) and returns the JWT to forward.
      (phantom_token) {
        forward_auth auth:4568 {
          uri /auth/jwt
          copy_headers Authorization
        }
      }

      :8901 {
        # route keeps the written order: Traefik answers CORS preflights
        # before authentication runs.
        route {
          @preflight {
            method OPTIONS
            path /api/* /video*
          }
          handle @preflight {
            import cors
            respond 204
          }
          @auth path /auth/* /.well-known/*
          handle @auth {
            reverse_proxy auth:4568
          }
          handle /swagger* {
            reverse_proxy api:3567
          }
          handle /api/* {
            import cors
            import phantom_token
            reverse_proxy api:3567
          }
          handle /video* {
            import cors
            import phantom_token
            reverse_proxy transcoder:7666
          }
          handle /scanner/* {
            import phantom_token
            reverse_proxy scanner:4389
          }
          handle {
            reverse_proxy front:8901
          }
        }
      }
    '';
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.kyoo-edge = {
        image = "docker.io/library/caddy:2.10-alpine";
        volumes = ["${caddyfile}:/etc/caddy/Caddyfile:ro"];
        ports = ["127.0.0.1:${toString cfg.port}:8901/tcp"];
        dependsOn = ["kyoo-api" "kyoo-auth" "kyoo-front" "kyoo-scanner" "kyoo-transcoder"];
      };

      # Public: TVs and the mobile app stream from outside the tailnet.
      # Kyoo's own auth (Pocket ID only, no guests) guards it.
      services.homelab.caddy.virtualHosts.kyoo = {
        inherit (cfg) domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
