{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.caddy;

    acmeEmail = "admin@zekurio.me";

    # Helper to replace generic matchers with service-specific ones
    makeMatchersUnique = name: config: let
      # Replace @blocked with @blocked_<servicename>
      uniqueBlockedMatcher = "@blocked_${name}";
    in
      builtins.replaceStrings ["@blocked"] [uniqueBlockedMatcher] config;

    # Group virtual hosts by domain and merge their configurations
    groupedHosts = lib.foldl' (
      acc: name: let
        hostCfg = cfg.virtualHosts.${name};
        domain = hostCfg.domain or name;
        existing =
          acc.${
            domain
          } or {
            reverseProxies = [];
            extraConfigs = [];
            forwardAuth = null;
            authPaths = [];
          };
        # Make matchers unique to avoid conflicts
        uniqueExtraConfig =
          if hostCfg.extraConfig != ""
          then makeMatchersUnique name hostCfg.extraConfig
          else "";
      in
        acc
        // {
          ${domain} = {
            reverseProxies =
              existing.reverseProxies
              ++ (lib.optional (hostCfg.reverseProxy or null != null) hostCfg.reverseProxy);
            extraConfigs = existing.extraConfigs ++ (lib.optional (uniqueExtraConfig != "") uniqueExtraConfig);
            # First non-null forwardAuth across all entries for this domain wins
            forwardAuth =
              if hostCfg.forwardAuth != null
              then hostCfg.forwardAuth
              else existing.forwardAuth;
            authPaths = lib.unique (existing.authPaths ++ hostCfg.authPaths);
          };
        }
    ) {} (builtins.attrNames cfg.virtualHosts);
  in {
    options.services.homelab.caddy = {
      enable =
        lib.mkEnableOption "Caddy reverse proxy with Cloudflare DNS"
        // {
          default = true;
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
              forwardAuth = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "oauth2-proxy address for forward auth (e.g. 127.0.0.1:4180). When set, all requests to this domain (except /oauth2/*) are gated behind Pocket ID.";
              };
              authPaths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = ''
                  Path matchers to restrict forward auth to, e.g. ["/lidarr*"].
                  Empty gates the whole domain. Use this when several services
                  share a domain and only some of them need gating, such as an
                  admin UI sitting next to an app that does its own auth.
                '';
              };
            };
          }
        );
        default = {};
        description = "Virtual host configurations for Caddy";
      };
    };

    config = lib.mkIf (cfg.enable && cfg.virtualHosts != {}) {
      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          # v0.2.4 is the first release that accepts Cloudflare's prefixed
          # token format (cfut_...); older builds reject those outright.
          plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
          hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
        };
        globalConfig = ''
          email ${acmeEmail}
          acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN} {
            resolvers 1.1.1.1 1.0.0.1
          }
          servers {
            listener_wrappers {
              proxy_protocol {
                timeout 5s
                allow 127.0.0.1/32
              }
              tls
            }
            trusted_proxies static 127.0.0.1/32
          }
        '';
        virtualHosts =
          lib.mapAttrs (_: hostCfg: {
            extraConfig = ''
              header {
                X-Robots-Tag "noindex, nofollow"
              }
              tls {
                dns cloudflare {env.CLOUDFLARE_API_TOKEN}
                resolvers 1.1.1.1 1.0.0.1
              }
              ${lib.optionalString (hostCfg.forwardAuth != null) ''
                handle /oauth2/* {
                  reverse_proxy ${hostCfg.forwardAuth}
                }
                # Bypass token: skip OIDC for API clients (e.g. nzb360)
                @not_bypass {
                  not header X-Bypass-Token {$CADDY_BYPASS_TOKEN}
                  not path /oauth2/*
                  ${lib.optionalString (hostCfg.authPaths != []) "path ${lib.concatStringsSep " " hostCfg.authPaths}"}
                }
                forward_auth @not_bypass ${hostCfg.forwardAuth} {
                  uri /oauth2/auth
                  copy_headers X-Auth-Request-User X-Auth-Request-Email X-Auth-Request-Groups
                  @unauthorized status 401
                  handle_response @unauthorized {
                    redir * /oauth2/start?rd={http.request.uri} 302
                  }
                }
              ''}
              ${lib.concatStringsSep "\n" hostCfg.extraConfigs}
              ${lib.optionalString (
                hostCfg.reverseProxies != [] && builtins.length hostCfg.reverseProxies == 1
              ) "reverse_proxy ${builtins.head hostCfg.reverseProxies}"}
            '';
          })
          groupedHosts;
      };

      # Make Cloudflare API token and email available to Caddy
      systemd.services.caddy.serviceConfig = {
        EnvironmentFile = [config.sops.secrets.caddy_env.path];
      };

      # SOPS secret for Caddy environment variables
      sops.secrets.caddy_env = {
        owner = "caddy";
        group = "caddy";
        mode = "0400";
        # EnvironmentFile is read once at start, so a rotated Cloudflare or
        # bypass token would otherwise stay unused until an unrelated restart.
        restartUnits = ["caddy.service"];
      };

      # Open firewall ports for HTTP/HTTPS
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
      networking.firewall.allowedUDPPorts = [443];
    };
  };
}
