{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.dashthing;
    schnitzelflix = config.services.homelab.domains.schnitzelflix;
    domain = "dash.${config.services.homelab.domains.zekurio}";
    port = 8090;
    package = inputs.dashthing.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    imports = [
      inputs.dashthing.nixosModules.default
    ];

    options.services.homelab.dashthing = {
      enable = lib.mkEnableOption "Jellyfin dashboard (recent additions, release calendar, costs) with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.radarr.enable;
          message = "services.homelab.dashthing requires services.homelab.radarr.";
        }
        {
          assertion = config.services.homelab.sonarr.enable;
          message = "services.homelab.dashthing requires services.homelab.sonarr.";
        }
        {
          assertion = config.services.homelab.jellyfin.enable;
          message = "services.homelab.dashthing requires services.homelab.jellyfin.";
        }
      ];

      services.dashthing = {
        enable = true;
        inherit package;
        environmentFile = config.sops.templates."dashthing.env".path;
        settings = {
          listen = "127.0.0.1:${toString port}";
          # The one place the public address lives; change it here to move the app.
          base_url = "https://${domain}";
          branding = {
            name = "SchnitzelFlix";
            icon_url = "";
            page_title = "";
            description = "Neues, Kommendes und die Kosten von SchnitzelFlix.";
          };
          jellyfin = {
            url = config.services.homelab.jellyfin.baseUrl;
            public_url = config.services.homelab.jellyfin.publicUrl;
            api_key = "\${JELLYFIN_API_KEY}";
          };
          library.limit = 24;
          calendar = {
            cache_ttl = "10m";
            past_days = 30;
            future_days = 90;
            name = "SchnitzelFlix";
            availability_delay = "1h";
            feed_secret = "\${DASHTHING_FEED_SECRET}";
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
          # Lives in the unit's StateDirectory; see the migration step below.
          costs.data_file = "/var/lib/dashthing/costs.json";
        };
      };

      # The feed secret keeps its calthing-era sops name, so existing feed
      # tokens stay valid and the secrets file needs no edit.
      sops.templates."dashthing.env" = {
        content = ''
          RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
          SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
          JELLYFIN_API_KEY=${config.sops.placeholder.jellyfin_api_key}
          DASHTHING_FEED_SECRET=${config.sops.placeholder.calthing_feed_secret}
        '';
        mode = "0400";
      };
      sops.secrets = {
        radarr_api_key = {};
        sonarr_api_key = {};
        jellyfin_api_key = {};
        calthing_feed_secret = {};
      };

      systemd.services.dashthing = {
        # One-time move from costthing: seed the cost file from the old state
        # directory if dashthing has none yet. "+" runs it as root, because the
        # dynamic service user cannot read /var/lib/costthing. Safe to delete
        # once adam has started dashthing for the first time.
        serviceConfig.ExecStartPre = "+${pkgs.writeShellScript "dashthing-import-costthing" ''
          set -eu
          old=/var/lib/costthing/costs.json
          new=/var/lib/dashthing/costs.json
          if [ ! -e "$new" ] && [ -e "$old" ]; then
            ${pkgs.coreutils}/bin/install -m 0600 "$old" "$new"
            ${pkgs.coreutils}/bin/chown --reference=/var/lib/dashthing/ "$new"
          fi
        ''}";
        after = [
          "jellyfin.service"
          "radarr.service"
          "sonarr.service"
        ];
        wants = [
          "jellyfin.service"
          "radarr.service"
          "sonarr.service"
        ];
      };

      services.homelab.caddy.virtualHosts = {
        dashthing = {
          inherit domain;
          public = true;
          reverseProxy = "127.0.0.1:${toString port}";
        };
        # The addresses calthing and costthing used to live at.
        dashthing-calendar = {
          domain = "calendar.${schnitzelflix}";
          public = true;
          extraConfig = "redir https://${domain}/calendar permanent";
        };
        dashthing-costs = {
          domain = "costs.${schnitzelflix}";
          public = true;
          extraConfig = "redir https://${domain}/costs permanent";
        };
      };
    };
  };
}
