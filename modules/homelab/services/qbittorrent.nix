{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  domain = "qbit.schnitzelflix.xyz";
  webuiPort = 8080;
  torrentingPort = 6881;
in {
  options.services.qbittorrent-wrapped = {
    enable = lib.mkEnableOption "qBittorrent with VPN confinement";
  };

  config = lib.mkIf config.services.qbittorrent-wrapped.enable {
    services.qbittorrent = {
      enable = true;
      user = shareUser;
      group = shareGroup;
      webuiPort = webuiPort;
      torrentingPort = torrentingPort;
      openFirewall = false; # Managed through VPN namespace

      # Note: serverConfig is intentionally not set to allow persistent
      # configuration through the WebUI. Configure qBittorrent settings
      # (including password) directly in the web interface.
      # Changes will be saved to /var/lib/qBittorrent/qBittorrent/config/

      extraArgs = ["--confirm-legal-notice"];
    };

    systemd.services.qbittorrent.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."qbittorrent" = {
      domain = domain;
      extraConfig = ''
        reverse_proxy 192.168.15.1:${toString webuiPort}
      '';
    };
  };
}
