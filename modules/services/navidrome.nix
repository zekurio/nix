{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
in {
  options.services.navidrome-wrapped = {
    enable = lib.mkEnableOption "Navidrome music server with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "nv.zekurio.xyz";
      description = "Domain name for Navidrome";
    };
    musicFolder = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/fast-nvme/media/music";
      description = "Path to music folder";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 4533;
      description = "Port for Navidrome to listen on";
    };
  };

  config = lib.mkIf config.services.navidrome-wrapped.enable {
    # SOPS secret for Spotify environment variables
    sops.secrets.navidrome_env = {
      owner = shareUser;
      group = shareGroup;
      mode = "0400";
    };

    services.navidrome = {
      enable = true;
      user = shareUser;
      group = shareGroup;
      settings = {
        MusicFolder = config.services.navidrome-wrapped.musicFolder;
        Address = "127.0.0.1";
        Port = config.services.navidrome-wrapped.port;
        BaseUrl = "/";
        # Scan interval for detecting new artwork
        ScanInterval = "5m";
      };
      openFirewall = true;
    };

    # Create cache directory with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/cache/navidrome 0775 ${shareUser} ${shareGroup} -"
    ];

    # Ensure navidrome service can access music files with group permissions
    systemd.services.navidrome.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce "0002";
      # Use system library reading to avoid permission issues
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        config.services.navidrome-wrapped.musicFolder
        "/var/cache/navidrome"
        "/var/lib/navidrome"
      ];
      # Allow reading parent directories for traversal
      BindReadOnlyPaths = [
        "/mnt/fast-nvme"
      ];
      # Load Spotify credentials from sops secrets
      EnvironmentFile = config.sops.secrets.navidrome_env.path;
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."navidrome" = {
      domain = config.services.navidrome-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.navidrome-wrapped.port}";
    };
  };
}
