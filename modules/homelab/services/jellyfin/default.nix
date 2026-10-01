{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.jellyfin;
    ferrofin = cfg.backend == "ferrofin";
    mediaShare = config.modules.homelab.mediaShare;
    domain = config.services.homelab.domains.schnitzelflix;
    port = cfg.port;
    serviceUser = "jellyfin";
    serviceGroup = "jellyfin";
    landingPage = pkgs.writeTextDir "index.html" (
      builtins.replaceStrings ["@serverUrl@"]
      [(lib.escapeXML cfg.publicUrl)]
      (builtins.readFile ./landing.html)
    );
  in {
    options.services.homelab.jellyfin = {
      enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
      backend = lib.mkOption {
        type = lib.types.enum ["jellyfin" "ferrofin"];
        default = "jellyfin";
        description = "Server that provides the Jellyfin API. Each backend has its own data directory.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8096;
        description = "Local HTTP port Jellyfin listens on.";
      };
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString cfg.port}";
        description = "Internal URL other services use to reach the Jellyfin API.";
      };
      publicUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://${domain}";
        description = "Public URL users and external clients use to reach Jellyfin.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        package =
          if ferrofin
          then pkgs.callPackage ./_ferrofin.nix {}
          else pkgs.jellyfin;
        # Native ports stay closed; external clients reach Jellyfin through
        # the public Caddy vhost on 443.
        openFirewall = false;
        dataDir =
          if ferrofin
          then "/var/lib/ferrofin"
          else "/var/lib/jellyfin";
        cacheDir =
          if ferrofin
          then "/var/cache/ferrofin"
          else "/var/cache/jellyfin";
      };

      environment.systemPackages = [
        config.services.jellyfin.package
        pkgs.jellyfin-web
        pkgs.jellyfin-ffmpeg
      ];

      systemd.tmpfiles.rules = [
        "d ${config.services.jellyfin.cacheDir} 2775 ${serviceUser} ${serviceGroup} -"
      ];

      systemd.services.jellyfin = {
        # Keep the unit and account names: other services use the Jellyfin API
        # and Inviterr reads password reset files through the Jellyfin group.
        description = lib.mkIf ferrofin (lib.mkForce "Ferrofin media server");
        path = lib.mkIf ferrofin [pkgs.rsync];
        preStart = lib.mkIf ferrofin ''
          ${pkgs.bash}/bin/bash ${./migrate.sh} /var/lib/jellyfin ${lib.escapeShellArg config.services.jellyfin.dataDir}
        '';
        environment =
          {LIBVA_DRIVER_NAME = "iHD";}
          // lib.optionalAttrs ferrofin {
            FERROFIN_DATA_DIR = config.services.jellyfin.dataDir;
            FERROFIN_CONFIG_DIR = config.services.jellyfin.configDir;
            FERROFIN_CACHE_DIR = config.services.jellyfin.cacheDir;
            FERROFIN_WEB_DIR = "${pkgs.jellyfin-web}/share/jellyfin-web";
            FERROFIN_BIND_ADDR = "127.0.0.1";
            FERROFIN_PORT = toString port;
            FERROFIN_PUBLISHED_URL = cfg.publicUrl;
            FERROFIN_FFMPEG_PATH = "${pkgs.jellyfin-ffmpeg}/bin/ffmpeg";
            FERROFIN_FFPROBE_PATH = "${pkgs.jellyfin-ffmpeg}/bin/ffprobe";
          };
        serviceConfig = {
          UMask = lib.mkForce mediaShare.umask;
          ReadWritePaths = [
            config.services.jellyfin.cacheDir
            config.services.jellyfin.dataDir
          ];
          ReadOnlyPaths = lib.mkIf ferrofin ["-/var/lib/jellyfin"];
          ExecStart = lib.mkIf ferrofin (lib.mkForce (lib.getExe config.services.jellyfin.package));
          # The initial metadata copy can take longer than the normal startup.
          TimeoutStartSec = lib.mkIf ferrofin "infinity";
          TimeoutStopSec = lib.mkIf ferrofin 45;
        };
      };

      users.users.jellyfin.extraGroups = [
        "render"
        "video"
      ];

      services.homelab.caddy.virtualHosts."jellyfin" = {
        domain = domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
        extraConfig = ''
          # URL fragments such as #/home never reach Caddy. Replace the web
          # routes for public visitors, leaving API and streaming paths alone.
          @blocked {
            path / /web /web/*
            not remote_ip ${lib.concatStringsSep " " config.services.homelab.caddy.privateRanges}
            # Jellium loads the server's web UI but uses mpv for playback.
            # This spoofable app identifier is a UX exception, not authentication.
            not header User-Agent *jellium-desktop/*
          }
          handle @blocked {
            root * ${landingPage}
            rewrite * /index.html
            header Cache-Control "no-store"
            file_server
          }
        '';
      };
    };
  };
}
