{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.alloy-clips;
  domain = "clips.zekurio.xyz";
  port = 3000;
in {
  options.services.homelab.alloy-clips = {
    enable = lib.mkEnableOption "Alloy clip sharing server with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.alloy-clips = {
      enable = true;
      package = inputs.alloy.packages.${pkgs.stdenv.hostPlatform.system}.alloy;
      inherit port;
      publicServerUrl = "https://${domain}";
      database.name = "alloy-clips";
    };

    services.homelab.caddy.virtualHosts."alloy-clips" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
