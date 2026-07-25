{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.aurral;
    mediaShare = config.modules.homelab.mediaShare;
    domain = "aurral.${config.services.homelab.domains.zekurio}";
    port = 3001;
    configDir = "/var/lib/aurral";
    shareUid = toString config.users.users.${mediaShare.user}.uid;
    shareGid = toString config.users.groups.${mediaShare.group}.gid;
  in {
    options.services.homelab.aurral = {
      enable = lib.mkEnableOption "Aurral music discovery companion for Lidarr (Docker container)";

      image = lib.mkOption {
        type = lib.types.str;
        # v2 has no tagged release yet: upstream releases are still v1.76.x and
        # v2 lives on the `test` branch. Pin the digest so the moving `test`
        # tag cannot change what gets deployed.
        default = "ghcr.io/lklynet/aurral@sha256:a2ce2e4ae4767c3fb445728c3af2e972823b874c7813d290a2054b736100bbf6";
        description = "Container image to run. Pin by digest; `test` is the v2 pre-release tag.";
      };

      trustedProxyIps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # Published ports are DNAT'd through the podman bridge, so requests
        # proxied from Caddy on the host reach the container with the gateway
        # address as their source, not 127.0.0.1.
        default = ["10.88.0.1" "127.0.0.1"];
        description = ''
          Addresses allowed to assert identity via the x-forwarded-user header.
          Without this, anything able to reach the container port can
          impersonate any user.
        '';
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Optional env file for secrets such as SESSION_SECRET or third-party
          API keys. Integrations (Lidarr, slskd, Navidrome, Last.fm) are
          normally configured in the Aurral UI and stored in its own database.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.aurral = {
        image = cfg.image;
        autoStart = true;

        # Aurral reaches Lidarr, slskd and Navidrome on the host loopback.
        # Podman maps host.containers.internal to the host gateway, so the UI
        # integrations use http://host.containers.internal:<port>.
        extraOptions = ["--add-host=host.containers.internal:host-gateway"];

        environment = {
          PUID = shareUid;
          PGID = shareGid;
          TZ = config.time.timeZone;
          # Caddy already gates this vhost behind Pocket ID, so trust the
          # upstream identity header instead of a second login prompt.
          AUTH_PROXY_ENABLED = "true";
          AUTH_PROXY_TRUSTED_IPS = lib.concatStringsSep "," cfg.trustedProxyIps;
        };

        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        ports = ["127.0.0.1:${toString port}:${toString port}"];

        volumes = [
          # v2 moved the state mount from /app/backend/data to /config
          "${configDir}:/config"
          # Aurral must see the media and download trees at exactly the paths
          # Lidarr uses, otherwise imports and file reuse resolve wrongly.
          "${mediaShare.musicDir}:${mediaShare.musicDir}"
          "${mediaShare.downloadsRoot}:${mediaShare.downloadsRoot}"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${configDir} 0750 ${shareUid} ${shareGid} -"
      ];

      services.homelab.caddy.virtualHosts."aurral" = {
        inherit domain;
        forwardAuth = config.services.homelab.oauth2-proxy.zekurio.forwardAuthAddress;
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString port} {
            header_up Host {http.request.host}
            # AUTH_PROXY_ENABLED expects the identity in x-forwarded-user;
            # oauth2-proxy supplies it as X-Auth-Request-User.
            header_up X-Forwarded-User {http.request.header.X-Auth-Request-User}
          }
        '';
      };
    };
  };
}
