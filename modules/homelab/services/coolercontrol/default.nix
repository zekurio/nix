{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.coolercontrol;
  domain = "cooling.zekurio.xyz";
  exposedTcpPorts =
    [cfg.port]
    ++ lib.optional cfg.exposeGrpc cfg.grpcPort;
in {
  options.services.homelab.coolercontrol = {
    enable = lib.mkEnableOption "CoolerControl daemon with LAN and Caddy integration";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11987;
      description = "CoolerControl web UI and REST API port.";
    };

    grpcPort = lib.mkOption {
      type = lib.types.port;
      default = 11988;
      description = "CoolerControl gRPC API port.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IPv4 bind address for coolercontrold.";
    };

    listenAddress6 = lib.mkOption {
      type = lib.types.str;
      default = "::1";
      description = "IPv6 bind address for coolercontrold.";
    };

    exposeGrpc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the gRPC port through the firewall as well.";
    };

    allowedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Network interfaces allowed to reach the exposed CoolerControl ports.";
    };

    caddy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose CoolerControl through the homelab Caddy reverse proxy.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = domain;
        description = "Domain used for the reverse-proxied CoolerControl UI.";
      };

      forwardAuth = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "127.0.0.1:4181";
        description = "oauth2-proxy forward-auth endpoint for the CoolerControl vhost.";
      };

      bearerTokenEnv = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Environment variable name holding the CoolerControl API bearer token. When set, Caddy injects Authorization: Bearer {env.VAR} on upstream requests. The variable must be present in Caddy's environment (e.g. via the caddy_env SOPS secret).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.coolercontrol.coolercontrold];

    systemd.packages = [pkgs.coolercontrol.coolercontrold];

    systemd.services.coolercontrold = {
      wantedBy = ["multi-user.target"];
      environment = {
        CC_HOST_IP4 = cfg.listenAddress;
        CC_HOST_IP6 = cfg.listenAddress6;
        CC_PORT = toString cfg.port;
        CC_LOG = "INFO";
      };
    };

    # CoolerControl persists its editable runtime configuration under /etc.
    systemd.tmpfiles.rules = [
      "d /etc/coolercontrol 0755 root root -"
    ];

    networking.firewall = lib.mkMerge [
      (lib.mkIf (cfg.allowedInterfaces == []) {
        allowedTCPPorts = exposedTcpPorts;
      })
      (lib.mkIf (cfg.allowedInterfaces != []) {
        interfaces = lib.genAttrs cfg.allowedInterfaces (_: {
          allowedTCPPorts = exposedTcpPorts;
        });
      })
    ];

    services.homelab.caddy.virtualHosts."coolercontrol" = lib.mkIf cfg.caddy.enable {
      domain = cfg.caddy.domain;
      forwardAuth = cfg.caddy.forwardAuth;
      reverseProxy = lib.mkIf (cfg.caddy.bearerTokenEnv == null) "127.0.0.1:${toString cfg.port}";
      extraConfig = lib.optionalString (cfg.caddy.bearerTokenEnv != null) ''
        reverse_proxy 127.0.0.1:${toString cfg.port} {
          header_up Authorization "Bearer {env.${cfg.caddy.bearerTokenEnv}}"
        }
      '';
    };
  };
}
