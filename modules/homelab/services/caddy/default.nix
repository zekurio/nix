{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.caddy;

    acmeEmail = "admin@zekurio.me";

    # Source ranges allowed to reach private virtual hosts: the home LAN and
    # the Tailscale tailnet (v4 and v6), plus loopback for local tooling and
    # health checks. Everything else gets a 404 before routing happens.
    privateRanges = ["10.0.0.0/24" "100.64.0.0/10" "fd7a:115c:a1e0::/48" "127.0.0.1" "::1"];
    privateRangesStr = lib.concatStringsSep " " privateRanges;

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
            public = false;
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
            # One public entry makes the whole domain public; a private
            # service sharing the domain must restrict its own paths in
            # extraConfig with a `@blocked` matcher (renamed per service by
            # makeMatchersUnique when merging).
            public = existing.public || hostCfg.public;
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

    config = lib.mkIf (cfg.enable && cfg.virtualHosts != {}) {
      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          # v0.2.4 is the first release that accepts Cloudflare's prefixed
          # token format (cfut_...); older builds reject those outright.
          plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
          hash = "sha256-dQvk6ezY6TQ1J7PjhCXnThF/SqVgPwBO8/RXzHCY+js=";
        };
        globalConfig = ''
          email ${acmeEmail}
          acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN} {
            resolvers 1.1.1.1 1.0.0.1
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
              ${lib.optionalString (!hostCfg.public) ''
                @not_local not remote_ip ${privateRangesStr}
                respond @not_local 404
              ''}
              ${lib.concatStringsSep "\n" hostCfg.extraConfigs}
              ${lib.optionalString (
                hostCfg.reverseProxies != [] && builtins.length hostCfg.reverseProxies == 1
              ) "reverse_proxy ${builtins.head hostCfg.reverseProxies}"}
            '';
          })
          groupedHosts;
      };

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
  };
}
