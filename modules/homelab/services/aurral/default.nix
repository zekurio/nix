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
        # v1.76.51, the current stable release (`latest`, 2026-07-07). The v2
        # pre-release on the `test` tag was tried and reverted: it is still too
        # unstable to run. Pin the digest so neither tag can move underneath us.
        default = "ghcr.io/lklynet/aurral@sha256:cf04da830f6965d9bd27d533eddddb0b3430390efe7b4f6f4338e486d4e3ec94";
        description = "Container image to run, pinned by digest. Currently aurral 1.76.51.";
      };

      defaultRole = lib.mkOption {
        type = lib.types.enum ["user" "admin"];
        default = "user";
        description = ''
          Role granted to identities arriving through the proxy auth header.
          Aurral defaults these to `user`, which cannot open its settings, so a
          deployment whose only entrance is the SSO-gated vhost has no way to
          administer itself until this is `admin`.
        '';
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
          AUTH_PROXY_DEFAULT_ROLE = cfg.defaultRole;
        };

        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        ports = ["127.0.0.1:${toString port}:${toString port}"];

        volumes = [
          # v1 keeps its SQLite database and caches here; /config is the v2
          # layout and this release does not read it.
          "${configDir}:/app/backend/data"
          # Aurral must see the media and download trees at exactly the paths
          # Lidarr uses, otherwise imports and file reuse resolve wrongly.
          "${mediaShare.musicDir}:${mediaShare.musicDir}"
          "${mediaShare.downloadsRoot}:${mediaShare.downloadsRoot}"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${configDir} 0750 ${shareUid} ${shareGid} -"
      ];

      # The container reaches Lidarr across the podman bridge, which the
      # default-deny input policy drops. Scope the opening to podman0 so the
      # port stays closed on the LAN and tailnet.
      #
      # Only Lidarr is reachable on purpose: slskd is driven by Lidarr's own
      # plugin now, so aurral has no reason to speak to it, and leaving those
      # ports open would let its optional slskd and Navidrome integrations be
      # switched on in the UI and quietly reintroduce a second acquisition path.
      networking.firewall.interfaces."podman0".allowedTCPPorts = [
        config.services.lidarr.settings.server.port
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
