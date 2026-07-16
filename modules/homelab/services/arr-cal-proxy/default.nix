{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.arr-cal-proxy;
    domain = "calendar.${config.services.homelab.domains.schnitzelflix}";
    port = 8090;
    package = inputs.arr-cal-proxy.packages.${pkgs.system}.default;
  in {
    imports = [
      inputs.arr-cal-proxy.nixosModules.default
    ];

    options.services.homelab.arr-cal-proxy = {
      enable = lib.mkEnableOption "merged Radarr and Sonarr calendar with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.radarr.enable;
          message = "services.homelab.arr-cal-proxy requires services.homelab.radarr.";
        }
        {
          assertion = config.services.homelab.sonarr.enable;
          message = "services.homelab.arr-cal-proxy requires services.homelab.sonarr.";
        }
        {
          assertion = config.services.homelab.jellyfin.enable;
          message = "services.homelab.arr-cal-proxy requires services.homelab.jellyfin.";
        }
      ];

      services.arr-cal-proxy = {
        enable = true;
        inherit package;
        environmentFile = config.sops.templates."arr-cal-proxy.env".path;
        settings = {
          listen = "127.0.0.1:${toString port}";
          cache.ttl = "10m";
          calendar = {
            past_days = 30;
            future_days = 90;
            name = "SchnitzelFlix";
            availability_delay = "1h";
          };
          auth.token = "";
          branding = {
            name = "SchnitzelFlix";
            icon_url = "";
            page_title = "SchnitzelFlix · Programm";
            description = "Das gemeinsame Film- und Serienprogramm von SchnitzelFlix.";
          };
          jellyfin = {
            url = config.services.homelab.jellyfin.baseUrl;
            public_url = "https://${config.services.homelab.domains.schnitzelflix}";
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

      sops.templates."arr-cal-proxy.env" = {
        content = ''
          RADARR_API_KEY=${config.sops.placeholder.anvil_radarr_api_key}
          SONARR_API_KEY=${config.sops.placeholder.anvil_sonarr_api_key}
          JELLYFIN_API_KEY=${config.sops.placeholder.arr_cal_proxy_jellyfin_api_key}
        '';
        mode = "0400";
      };
      sops.secrets = {
        anvil_radarr_api_key = {};
        anvil_sonarr_api_key = {};
        arr_cal_proxy_jellyfin_api_key = {};
      };

      systemd.services.arr-cal-proxy = {
        after = [
          "radarr.service"
          "sonarr.service"
        ];
        wants = [
          "radarr.service"
          "sonarr.service"
        ];
      };

      services.homelab.caddy.virtualHosts."arr-cal-proxy" = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
