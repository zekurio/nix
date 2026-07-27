{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.calthing;
    domain = "calendar.${config.services.homelab.domains.schnitzelflix}";
    port = 8090;
    package = inputs.calthing.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    imports = [
      inputs.calthing.nixosModules.default
    ];

    options.services.homelab.calthing = {
      enable = lib.mkEnableOption "merged Radarr and Sonarr calendar with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.radarr.enable;
          message = "services.homelab.calthing requires services.homelab.radarr.";
        }
        {
          assertion = config.services.homelab.sonarr.enable;
          message = "services.homelab.calthing requires services.homelab.sonarr.";
        }
        {
          assertion = config.services.homelab.jellyfin.enable;
          message = "services.homelab.calthing requires services.homelab.jellyfin.";
        }
      ];

      services.calthing = {
        enable = true;
        inherit package;
        environmentFile = config.sops.templates."calthing.env".path;
        settings = {
          listen = "127.0.0.1:${toString port}";
          cache.ttl = "10m";
          calendar = {
            past_days = 30;
            future_days = 90;
            name = "SchnitzelFlix";
            availability_delay = "1h";
            feed_secret = "\${CALTHING_FEED_SECRET}";
          };
          branding = {
            name = "SchnitzelFlix";
            icon_url = "";
            page_title = "SchnitzelFlix · Programm";
            description = "Das gemeinsame Film- und Serienprogramm von SchnitzelFlix.";
          };
          jellyfin = {
            url = config.services.homelab.jellyfin.baseUrl;
            public_url = config.services.homelab.jellyfin.publicUrl;
            api_key = "\${JELLYFIN_API_KEY}";
          };
          instances = [
            {
              name = "Radarr";
              type = "radarr";
              url = config.services.homelab.radarr.baseUrl;
              api_key = "\${RADARR_API_KEY}";
              include_unmonitored = false;
            }
            {
              name = "Sonarr";
              type = "sonarr";
              url = config.services.homelab.sonarr.baseUrl;
              api_key = "\${SONARR_API_KEY}";
              include_unmonitored = false;
            }
          ];
        };
      };

      sops.templates."calthing.env" = {
        content = ''
          RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
          SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
          JELLYFIN_API_KEY=${config.sops.placeholder.jellyfin_api_key}
          CALTHING_FEED_SECRET=${config.sops.placeholder.calthing_feed_secret}
        '';
        mode = "0400";
      };
      sops.secrets = {
        radarr_api_key = {};
        sonarr_api_key = {};
        jellyfin_api_key = {};
        calthing_feed_secret = {};
      };

      systemd.services.calthing = {
        after = [
          "radarr.service"
          "sonarr.service"
        ];
        wants = [
          "radarr.service"
          "sonarr.service"
        ];
      };

      services.homelab.caddy.virtualHosts."calthing" = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
