{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.caddy-wrapper;

  acmeEmail = "admin@zekurio.xyz";

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
        };
      }
  ) {} (builtins.attrNames cfg.virtualHosts);
in {
  options.services.caddy-wrapper = {
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
        plugins = ["github.com/caddy-dns/cloudflare@v0.2.1"];
        hash = "sha256-Zls+5kWd/JSQsmZC4SRQ/WS+pUcRolNaaI7UQoPzJA0=";
      };
      globalConfig = ''
        email ${acmeEmail}
      '';
      virtualHosts =
        lib.mapAttrs (_: hostCfg: {
          extraConfig = ''
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
    };

    # Open firewall ports for HTTP/HTTPS
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    networking.firewall.allowedUDPPorts = [443];
  };
}
