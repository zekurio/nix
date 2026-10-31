{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
  fluxer = config.services.fluxer;
  socket = "/run/caddy/fluxer-edge.sock";
  proxy = targets: ''
    reverse_proxy ${lib.concatStringsSep " " (lib.toList targets)} {
      lb_try_duration 5s
      # The homelab vhost in front set this to the client's address. Only
      # Caddy can open the socket, so nothing else can claim another.
      header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
      header_up X-Real-IP {http.request.header.X-Forwarded-For}
      header_up -Forwarded
    }
  '';
in {
  config = lib.mkIf cfg.enable {
    # fluxer-nix's edge would add its routes to the public site itself.
    # Caddy runs handle blocks before the homelab vhost's LAN-only respond,
    # so the catch-all route would serve everyone. The routes live on a
    # site on a socket instead, behind the vhost, as they did in the old edge
    # container. Keep them in step with fluxer-nix's modules/edge.nix.
    services.fluxer.edge.enable = false;
    # fluxer-nix turns voice on only with its own edge serving /livekit.
    services.fluxer.livekit.url = "${fluxer.publicOrigin}/livekit";

    systemd.services.caddy.serviceConfig.RuntimeDirectory = "caddy";
    # No host, so it answers whatever host the vhost passes on.
    services.caddy.virtualHosts."http://" = {
      # The vhost in front logs every request already.
      logFormat = null;
      extraConfig = ''
        bind unix/${socket}|0600

        handle /_health {
          respond "OK" 200
        }

        handle_path /api/* {
          ${proxy fluxer.endpoints.api}
        }

        handle /gateway {
          rewrite * /
          ${proxy fluxer.endpoints.gateway}
        }

        handle_path /gateway/* {
          ${proxy fluxer.endpoints.gateway}
        }

        handle_path /media/* {
          ${proxy fluxer.endpoints.mediaProxy}
        }

        handle_path /livekit/* {
          ${proxy fluxer.endpoints.livekit}
        }

        handle ${fluxer.admin.basePath} {
          rewrite * /
          ${proxy fluxer.endpoints.admin}
        }

        handle_path ${fluxer.admin.basePath}/* {
          ${proxy fluxer.endpoints.admin}
        }

        @staticAssets path /web/* /emoji/* /libs/* /avatars/* /badges/* /desktop/*
        handle @staticAssets {
          root * ${fluxer.edge.staticPackage}
          header {
            X-Content-Type-Options nosniff
            Referrer-Policy strict-origin-when-cross-origin
            X-Frame-Options DENY
            Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
            Access-Control-Allow-Origin *
            Cache-Control "public, max-age=3600, must-revalidate"
            -Server
          }
          @hashedBadges path_regexp ^/badges/[0-9a-f]{16}\.(webp|png)$
          header @hashedBadges {
            defer
            Cache-Control "public, max-age=31536000, immutable"
          }
          file_server
        }

        handle /.well-known/fluxer {
          ${proxy fluxer.endpoints.api}
        }

        handle /.well-known/webfinger {
          ${proxy fluxer.endpoints.api}
        }

        handle {
          ${proxy fluxer.endpoints.appProxy}
        }
      '';
    };

    services.homelab.caddy.virtualHosts.fluxer = {
      domain = fluxer.domain;
      reverseProxy = "unix/${socket}";
    };
  };
}
