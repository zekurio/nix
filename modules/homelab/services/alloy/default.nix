{
  config,
  inputs,
  lib,
  ...
}: let
  domain = "clips.zekurio.me";
  port = 2552;
in {
  imports = [
    inputs.alloy.nixosModules.default
  ];

  options.services.homelab.alloy = {
    enable = lib.mkEnableOption "Alloy clip sharing with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.alloy.enable {
    services.alloy-clips = {
      enable = true;
      port = port;
      publicServerUrl = "https://${domain}";
      storageDir = "/tank/alloy/storage";
      accelerationDevices = ["/dev/dri/renderD128"];
      extraGroups = ["render" "video"];
    };

    systemd.services.alloy-clips = {
      requires = ["tank-datasets.service"];
      after = ["tank-datasets.service"];
    };

    services.homelab.caddy.virtualHosts."alloy" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
