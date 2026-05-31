{
  config,
  lib,
  ...
}: let
  domain = "clips.zekurio.me";
  port = 3000;
in {
  options.services.homelab.alloy = {
    enable = lib.mkEnableOption "Alloy clip sharing with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.alloy.enable {
    services.alloy-clips = {
      enable = true;
      port = port;
      publicServerUrl = "https://${domain}";
      storageDir = "/tank/alloy/storage";
      database.createLocally = true;
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
