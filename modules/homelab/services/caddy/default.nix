{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.caddy;

  acmeEmail = "admin@zekurio.me";

  # Services sharing a domain merge into one site. Each service's `@blocked`
  # matcher is renamed after the service so merged sites keep them apart.
  sites =
    lib.mapAttrs (_: hosts: {
      reverseProxies = lib.filter (proxy: proxy != null) (map (host: host.reverseProxy) hosts);
      extraConfigs =
        map (host: builtins.replaceStrings ["@blocked"] ["@blocked_${host.name}"] host.extraConfig)
        (lib.filter (host: host.extraConfig != "") hosts);
      # One public entry makes the whole domain public; a private service
      # sharing the domain must restrict its own paths in extraConfig with
      # a `@blocked` matcher.
      public = lib.any (host: host.public) hosts;
    })
    (lib.groupBy (host: host.domain)
      (lib.mapAttrsToList (name: host: host // {inherit name;}) cfg.virtualHosts));
in {
  options.services.homelab.caddy = {
    privateRanges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["10.0.0.0/24" "100.64.0.0/10" "fd7a:115c:a1e0::/48" "127.0.0.1" "::1"];
      description = "Source ranges allowed private access: the home LAN, Tailscale, and loopback.";
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            domain = lib.mkOption {
              type = lib.types.str;
              description = "Domain name (can be shared across multiple services)";
            };
            reverseProxy = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Backend address to proxy to (e.g., localhost:8096)";
            };
            extraConfig = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Extra Caddy configuration for this virtual host";
            };
            public = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Serve this domain to the internet. Private by default:
                without this flag the domain answers only the LAN and
                tailnet source ranges, everything else gets a 404.
              '';
            };
          };
        }
      );
      default = {};
      description = "Virtual host configurations for Caddy";
    };
  };

  config = lib.mkIf (cfg.virtualHosts != {}) {
    assertions =
      lib.mapAttrsToList (domain: site: {
        assertion = lib.length site.reverseProxies <= 1;
        message = "services.homelab.caddy: more than one service sets reverseProxy for ${domain}; proxy the others under their own paths in extraConfig.";
      })
      sites;

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        # v0.2.4 is the first release that accepts Cloudflare's prefixed
        # token format (cfut_...); older builds reject those outright.
        plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
        hash = "sha256-tubXIDCJnO2mvdnPlZclwDhNGaeeYLSt7lnni3+pXDo=";
      };
      globalConfig = ''
        email ${acmeEmail}
        acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN} {
          resolvers 1.1.1.1 1.0.0.1
        }
      '';
      virtualHosts =
        lib.mapAttrs (domain: site: {
          # Caddy keeps ten rolled 100 MiB files per site for 90 days by
          # default. Two weeks is enough to look into a problem.
          logFormat = ''
            output file ${config.services.caddy.logDir}/access-${domain}.log {
              roll_size 10MiB
              roll_keep 5
              roll_keep_for 14d
            }
          '';
          extraConfig = ''
            header {
              X-Robots-Tag "noindex, nofollow"
            }
            # Caddy has no global encode, so every site gets it here. Its
            # default matcher compresses only text-like types, leaving media
            # streams alone, and it skips WebSockets and flushes SSE as sent.
            encode zstd gzip
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
              resolvers 1.1.1.1 1.0.0.1
            }
            ${lib.optionalString (!site.public) ''
              @not_local not remote_ip ${lib.concatStringsSep " " cfg.privateRanges}
              respond @not_local 404
            ''}
            ${lib.concatStringsSep "\n" site.extraConfigs}
            ${lib.optionalString (site.reverseProxies != []) "reverse_proxy ${lib.head site.reverseProxies}"}
          '';
        })
        sites;
    };

    # Access logs only explain the past; a restore needs none of them.
    services.homelab.backup.exclude = ["${config.services.caddy.logDir}/"];

    # Make Cloudflare API token available to Caddy
    systemd.services.caddy.serviceConfig = {
      EnvironmentFile = [config.sops.secrets.caddy_env.path];
    };

    # SOPS secret for Caddy environment variables
    sops.secrets.caddy_env = {
      owner = "caddy";
      group = "caddy";
      mode = "0400";
      # EnvironmentFile is read once at start, so a rotated Cloudflare
      # token would otherwise stay unused until an unrelated restart.
      restartUnits = ["caddy.service"];
    };

    # Open firewall ports for HTTP/HTTPS (80 exists only for HTTP→HTTPS
    # redirects; UDP 443 is HTTP/3)
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    networking.firewall.allowedUDPPorts = [443];
  };
}
