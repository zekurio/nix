{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.coolercontrol;
    domain = "cc.${config.services.homelab.domains.zekurio}";
  in {
    options.services.homelab.coolercontrol = {
      enable = lib.mkEnableOption "CoolerControl daemon";

      port = lib.mkOption {
        type = lib.types.port;
        default = 11987;
        description = "CoolerControl web UI and REST API port.";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [pkgs.coolercontrol.coolercontrold];

      systemd.packages = [pkgs.coolercontrol.coolercontrold];

      systemd.services.coolercontrold = {
        wantedBy = ["multi-user.target"];
        environment = {
          CC_HOST_IP4 = "127.0.0.1";
          CC_HOST_IP6 = "::1";
          CC_PORT = toString cfg.port;
          CC_LOG = "INFO";
        };
      };

      # CoolerControl persists its editable runtime configuration under /etc.
      systemd.tmpfiles.rules = [
        "d /etc/coolercontrol 0755 root root -"
      ];

      services.homelab.caddy.virtualHosts.coolercontrol = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
