{ ... }: {
  imports = [
    ./autobrr.nix
    ./backups.nix
    ./caddy.nix
    ./fileflows.nix
    ./immich.nix
    ./jellyfin.nix
    ./jellyseerr.nix
    ./media-share.nix
    ./navidrome.nix
    ./paperless-ngx.nix
    ./prowlarr.nix
    ./qbittorrent.nix
    ./radarr.nix
    ./sabnzbd.nix
    ./sonarr.nix
    ./tailscale.nix
    ./vaultwarden.nix
  ];
}
