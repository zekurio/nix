{ config, lib, pkgs, ... }:

let
  shareUser = "share";
  shareGroup = "share";
in
{
  options.services.jellyfin-wrapped = {
    enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "schnitzelflix.xyz";
      description = "Domain name for Jellyfin";
    };
  };

  config = lib.mkIf config.services.jellyfin-wrapped.enable {
    services.jellyfin = {
      enable = false;
      openFirewall = true;
      user = shareUser;
      group = shareGroup;
    };

    # Use unstable jellyfin packages
    environment.systemPackages = [
      pkgs.jellyfin
      pkgs.jellyfin-web
      pkgs.jellyfin-ffmpeg
    ];

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."jellyfin" = {
      domain = config.services.jellyfin-wrapped.domain;
      reverseProxy = "localhost:8096";
    };
  };
}
