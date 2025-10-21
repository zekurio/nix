{ config, lib, ... }:

{
  options.services.qbittorrent-wrapped = {
    enable = lib.mkEnableOption "qBittorrent with VPN confinement";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "qbit.schnitzelflix.xyz";
      description = "Domain name for qBittorrent";
    };
    webuiPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for qBittorrent WebUI to listen on";
    };
    torrentingPort = lib.mkOption {
      type = lib.types.port;
      default = 6881;
      description = "Port for incoming torrent connections";
    };
  };

  config = lib.mkIf config.services.qbittorrent-wrapped.enable {
    services.qbittorrent = {
      enable = true;
      group = "media";
      webuiPort = config.services.qbittorrent-wrapped.webuiPort;
      torrentingPort = config.services.qbittorrent-wrapped.torrentingPort;
      openFirewall = false; # Managed through VPN namespace

      # Note: serverConfig is intentionally not set to allow persistent
      # configuration through the WebUI. Configure qBittorrent settings
      # (including password) directly in the web interface.
      # Changes will be saved to /var/lib/qBittorrent/qBittorrent/config/

      extraArgs = [ "--confirm-legal-notice" ];
    };

    # Configure qBittorrent service account to use media as primary group
    users.users.qbittorrent = {
      group = "media";
    };

    systemd.services.qbittorrent.serviceConfig = {
      UMask = lib.mkForce "0002";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."qbittorrent" = {
      domain = config.services.qbittorrent-wrapped.domain;
      reverseProxy = "192.168.15.1:${toString config.services.qbittorrent-wrapped.webuiPort}";
    };
  };
}
