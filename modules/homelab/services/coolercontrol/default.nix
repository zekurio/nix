{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.coolercontrol;
    exposedTcpPorts =
      [cfg.port]
      ++ lib.optional cfg.exposeGrpc cfg.grpcPort;
  in {
    options.services.homelab.coolercontrol = {
      enable = lib.mkEnableOption "CoolerControl daemon";

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
    };
  };
}
